#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""FusionRecorder-iOS 本机一键：推送 → 云端编译 → 取回未签名 .ipa

不想把 token 交给别人时，在自己电脑上运行这个脚本即可。只用 Python 标准库，
不需要装 git / Xcode / gh CLI。Token 只在本机内存里使用，不写文件、不打印。

用法（在工程根目录或任意目录都行）：
    python scripts/local_build.py                 # 提示粘贴 PAT，推送并等编译
    GITHUB_TOKEN=ghp_xxx python scripts/local_build.py   # 用环境变量给 token
    python scripts/local_build.py --no-push       # 已用网页上传过文件，只等 CI + 取 ipa

PAT 生成：https://github.com/settings/tokens → Generate new token (classic)
          → 勾选 repo + workflow → 复制 ghp_ 开头的串。
"""

import base64
import getpass
import json
import os
import pathlib
import re
import sys
import time
import urllib.error
import urllib.request
import zipfile

OWNER = "lathlee"
REPO = "FusionRecorder-iOS"
API = "https://api.github.com"
RAW = f"https://raw.githubusercontent.com/{OWNER}/{REPO}/ios-build/ci-logs"
ROOT = pathlib.Path(__file__).resolve().parent.parent

SKIP_DIRS = {".git", "ci-logs", "__pycache__", "DerivedData", ".build", "build"}
SKIP_FILES = {".DS_Store", "Thumbs.db"}
SKIP_SUFFIX = {".zip", ".pyc", ".ipa", ".app"}

try:
    sys.stdout.reconfigure(encoding="utf-8")
except Exception:
    pass


def say(msg):
    print(msg, flush=True)


def get_token(need_push):
    tok = os.environ.get("GITHUB_TOKEN", "").strip()
    if tok:
        say("令牌来源：环境变量 GITHUB_TOKEN")
        return tok
    if not need_push:
        return ""
    try:
        tok = getpass.getpass("粘贴 GitHub PAT（输入不回显，回车确认）：").strip()
    except Exception:
        tok = ""
    if not tok:
        say("!! 没拿到令牌。也可以不推送：先网页上传工程文件，再用 --no-push 只等编译结果")
        sys.exit(1)
    return tok


def req(method, path, payload=None, tok="", timeout=60):
    url = path if path.startswith("http") else API + path
    data = json.dumps(payload).encode("utf-8") if payload is not None else None
    headers = {
        "Accept": "application/vnd.github+json",
        "X-GitHub-Api-Version": "2022-11-28",
        "User-Agent": "FusionRecorder-local-build",
    }
    if tok:
        headers["Authorization"] = "Bearer " + tok
    if data is not None:
        headers["Content-Type"] = "application/json"
    request = urllib.request.Request(url, data=data, method=method, headers=headers)
    try:
        with urllib.request.urlopen(request, timeout=timeout) as resp:
            body = resp.read()
            return resp.status, (json.loads(body) if body else {}), dict(resp.headers)
    except urllib.error.HTTPError as error:
        raw = error.read() or b"{}"
        try:
            return error.code, json.loads(raw), dict(error.headers)
        except Exception:
            return error.code, {"message": raw.decode(errors="replace")[:200]}, {}
    except urllib.error.URLError as error:
        return 0, {"message": "网络错误: %s" % error.reason}, {}


def die(msg, payload=None):
    say("!! " + msg)
    if payload:
        say("   " + str(payload.get("message", payload))[:300])
    sys.exit(1)


def collect_files():
    items = []
    for path in sorted(ROOT.rglob("*")):
        if not path.is_file():
            continue
        rel = path.relative_to(ROOT)
        if any(part in SKIP_DIRS for part in rel.parts):
            continue
        if path.name in SKIP_FILES or path.suffix in SKIP_SUFFIX:
            continue
        if path.name.startswith("._"):
            continue
        items.append((rel.as_posix(), path))
    return items


def version():
    text = (ROOT / "project.yml").read_text(encoding="utf-8")
    match = re.search(r'MARKETING_VERSION:\s*"([^"]+)"', text)
    if not match:
        die("project.yml 里没找到 MARKETING_VERSION")
    return match.group(1)


def push(tok):
    files = collect_files()
    if not files:
        die("没有找到可推送的工程文件")
    say(f"推送 {len(files)} 个文件到 {OWNER}/{REPO} 的 main（单次提交）")

    # 空仓库时 Git Data API 的 POST /git/blobs 会返回 409 "Git Repository is empty"。
    # 先用 Contents API 放一个种子文件建立首个 commit（此时没有 workflow 文件，不会触发 Actions）。
    code, ref, _ = req("GET", f"/repos/{OWNER}/{REPO}/git/ref/heads/main", tok=tok)
    if code != 200:
        seed = ROOT / "README.md"
        content = base64.b64encode(seed.read_bytes()).decode("ascii")
        code, result, _ = req(
            "PUT", f"/repos/{OWNER}/{REPO}/contents/README.md",
            {"message": "chore: 初始化独立仓库", "content": content}, tok,
        )
        if code not in (200, 201):
            die("初始化空仓库失败（HTTP %s）" % code, result)
        say("空仓库已初始化（种子文件，不触发 Actions）")

    tree = []
    for index, (rel, path) in enumerate(files, 1):
        content = base64.b64encode(path.read_bytes()).decode("ascii")
        code, result, _ = req(
            "POST", f"/repos/{OWNER}/{REPO}/git/blobs",
            {"content": content, "encoding": "base64"}, tok,
        )
        if code not in (200, 201) or "sha" not in result:
            die(f"写 blob 失败 [{rel}] HTTP {code}（多半是 PAT 缺 repo 权限）", result)
        tree.append({"path": rel, "mode": "100644", "type": "blob", "sha": result["sha"]})
        if index % 5 == 0 or index == len(files):
            say(f"  blob {index}/{len(files)}")

    code, result, _ = req("POST", f"/repos/{OWNER}/{REPO}/git/trees", {"tree": tree}, tok)
    if code not in (200, 201):
        die("建 tree 失败", result)
    tree_sha = result["sha"]

    code, ref, _ = req("GET", f"/repos/{OWNER}/{REPO}/git/ref/heads/main", tok=tok)
    parents = [ref["object"]["sha"]] if code == 200 and "object" in ref else []

    code, result, _ = req(
        "POST", f"/repos/{OWNER}/{REPO}/git/commits",
        {"message": "feat: FusionRecorder-iOS v0.1 工程骨架 + 云端编译 workflow",
         "tree": tree_sha, "parents": parents}, tok,
    )
    if code not in (200, 201):
        die("建 commit 失败", result)
    commit_sha = result["sha"]

    if parents:
        code, result, _ = req("PATCH", f"/repos/{OWNER}/{REPO}/git/refs/heads/main",
                             {"sha": commit_sha, "force": True}, tok)
        action = "更新"
    else:
        code, result, _ = req("POST", f"/repos/{OWNER}/{REPO}/git/refs",
                             {"ref": "refs/heads/main", "sha": commit_sha}, tok)
        action = "创建"
    if code not in (200, 201):
        die(f"{action} main 失败", result)

    req("PATCH", f"/repos/{OWNER}/{REPO}", {"default_branch": "main"}, tok)
    say(f"已{action} main: {commit_sha[:12]}")


def ensure_run(tok, wait_seconds=120):
    """push 事件触发 workflow 需要几秒；超时则尝试手动 dispatch。"""
    deadline = time.time() + wait_seconds
    while time.time() < deadline:
        code, data, _ = req("GET", f"/repos/{OWNER}/{REPO}/actions/runs?per_page=1", tok=tok)
        runs = data.get("workflow_runs", []) if isinstance(data, dict) else []
        if runs:
            return runs[0]["id"]
        time.sleep(10)
    if tok:
        say("没等到 push 触发的 run，尝试 workflow_dispatch")
        code, data, _ = req(
            "POST", f"/repos/{OWNER}/{REPO}/actions/workflows/build-ipa.yml/dispatches",
            {"ref": "main"}, tok,
        )
        say(f"  dispatch HTTP {code}")
        if code == 204:
            time.sleep(10)
    return None


def wait_result(tok, timeout=1200):
    say(f"等待 GitHub Actions 编译（最长 {timeout // 60} 分钟）")
    deadline = time.time() + timeout
    last = ""
    while time.time() < deadline:
        code, data, _ = req("GET", f"/repos/{OWNER}/{REPO}/actions/runs?per_page=1", tok=tok)
        runs = data.get("workflow_runs", []) if isinstance(data, dict) else []
        if runs:
            run = runs[0]
            state = f"{run.get('status')}/{run.get('conclusion') or 'pending'}"
            if state != last:
                say("  状态: " + state)
                last = state
            if run.get("status") == "completed":
                return run
        time.sleep(15)
    return None


def fetch_text(url, timeout=60):
    try:
        with urllib.request.urlopen(url, timeout=timeout) as resp:
            return resp.read().decode("utf-8", errors="replace")
    except Exception as error:
        return "(读取失败: %s)" % error


def fetch_ipa(ver):
    url = f"{RAW}/FusionRecorder-{ver}-unsigned.ipa"
    dest_dir = ROOT / "ci-logs"
    dest_dir.mkdir(exist_ok=True)
    dest = dest_dir / f"FusionRecorder-{ver}-unsigned.ipa"
    say("下载产物: " + url)
    try:
        with urllib.request.urlopen(url, timeout=600) as resp:
            dest.write_bytes(resp.read())
    except Exception as error:
        die("IPA 下载失败（%s）" % error)
    if not dest.stat().st_size:
        die("IPA 是空文件")
    try:
        with zipfile.ZipFile(dest) as archive:
            if archive.testzip() is not None:
                die("IPA zip 校验失败")
            names = archive.namelist()
            has_app = any(n.startswith("Payload/") and n.endswith(".app/") for n in names)
            say(f"  zip 校验通过，{len(names)} 个条目，{dest.stat().st_size} 字节")
            if not has_app:
                say("  (提示：未在包内找到 Payload/*.app 目录，请检查构建日志)")
    except zipfile.BadZipFile:
        die("IPA 不是有效 zip")
    return dest


def main():
    no_push = "--no-push" in sys.argv or "--wait-only" in sys.argv
    say(f"== FusionRecorder-iOS 一键云端编译 ==\n   目标仓库: {OWNER}/{REPO}（独立仓库）")

    tok = get_token(need_push=not no_push)
    if tok:
        code, user, headers = req("GET", "/user", tok=tok)
        if code != 200 or "login" not in user:
            die("令牌无效（GET /user 失败）", user)
        scopes = headers.get("x-oauth-scopes", "")
        say(f"账号: {user['login']}" + (f" | scopes: {scopes}" if scopes else " | fine-grained / 无 scopes 头"))
        if scopes and "repo" not in scopes:
            say("  (提醒：classic PAT 需要勾 repo + workflow，否则推送会 403)")

    code, repo_info, _ = req("GET", f"/repos/{OWNER}/{REPO}", tok=tok)
    if code != 200:
        die(f"仓库 {OWNER}/{REPO} 不存在或不可见（HTTP {code}）", repo_info)
    say(f"仓库状态: {'空仓库' if repo_info.get('size') == 0 else '已有内容'} | 默认分支: {repo_info.get('default_branch')}")

    if not no_push:
        push(tok)
    else:
        say("--no-push：跳过推送，直接查编译结果（前提是工程文件已上传）")

    ensure_run(tok)
    run = wait_result(tok)

    if not run:
        die("等待超时，没有拿到构建结果。可到 https://github.com/%s/%s/actions 查看" % (OWNER, REPO))

    say("\n完整日志: https://github.com/%s/%s/actions/runs/%s" % (OWNER, REPO, run["id"]))
    if run.get("conclusion") != "success":
        say("!! 编译失败（%s），错误摘要：" % run.get("conclusion"))
        say(fetch_text(RAW + "/errors.txt")[:3000])
        say("\n把这段错误发给我，我改完代码你再跑一次本脚本即可。")
        sys.exit(1)

    ver = version()
    say("云端编译成功，版本 " + ver)
    fetch_text(RAW + "/last-build.md")  # 预热 raw 缓存，不打印全文
    dest = fetch_ipa(ver)
    say("\n完成：" + str(dest))
    say("侧载源：https://raw.githubusercontent.com/%s/%s/ios-build/ci-logs/source.json" % (OWNER, REPO))


if __name__ == "__main__":
    main()
