#!/usr/bin/env python3
"""用 GitHub Git Data API 一次性把整个工程提交到独立仓库的 main 分支。

为什么不用 git push：这个沙箱里 github.com:443 的 git smart HTTP 连不上，
而 api.github.com 是通的。走 API 还能保证「一次 commit → 只触发一次 workflow」。

用法: GITHUB_TOKEN=... push_via_api.py <owner> <repo> [工程根目录]
"""

import base64
import json
import os
import pathlib
import subprocess
import sys
import urllib.error
import urllib.request

TOKEN = os.environ.get("GITHUB_TOKEN", "")
if not TOKEN:
    sys.exit("缺少 GITHUB_TOKEN")

OWNER = sys.argv[1]
REPO = sys.argv[2]
ROOT = pathlib.Path(sys.argv[3]) if len(sys.argv) > 3 else pathlib.Path(".")
API = "https://api.github.com"
BASE = f"/repos/{OWNER}/{REPO}"


def req(method, path, payload=None, timeout=60):
    data = json.dumps(payload).encode() if payload is not None else None
    request = urllib.request.Request(
        API + path,
        data=data,
        method=method,
        headers={
            "Authorization": "Bearer " + TOKEN,
            "Accept": "application/vnd.github+json",
            "Content-Type": "application/json",
            "X-GitHub-Api-Version": "2022-11-28",
            "User-Agent": "FusionRecorder-iOS-build",
        },
    )
    try:
        with urllib.request.urlopen(request, timeout=timeout) as response:
            body = response.read()
            return response.status, json.loads(body) if body else {}
    except urllib.error.HTTPError as error:
        raw = error.read() or b"{}"
        try:
            return error.code, json.loads(raw)
        except Exception:
            return error.code, {"message": raw.decode(errors="replace")[:200]}


def main():
    # 1) 文件清单以本地 git 索引为准（.gitignore 已排除生成物）
    files = subprocess.check_output(
        ["git", "ls-files"], cwd=str(ROOT), text=True
    ).splitlines()
    if not files:
        sys.exit("没有可推送的文件")
    print(f"待提交文件: {len(files)} 个")

    # 1.5) 空仓库初始化：Git Data API 在完全空的仓库上 POST /git/blobs 会返回
    #      409 "Git Repository is empty"。先用 Contents API 放一个种子文件建立首个
    #      commit；此时仓库里还没有 workflow 文件，因此不会触发 Actions。
    code, ref = req("GET", f"{BASE}/git/ref/heads/main")
    if code != 200:
        seed = ROOT / "README.md"
        content = base64.b64encode(seed.read_bytes()).decode()
        code, result = req(
            "PUT", f"{BASE}/contents/README.md",
            {"message": "chore: 初始化独立仓库", "content": content},
        )
        if code not in (200, 201):
            sys.exit(f"初始化空仓库失败 HTTP {code}: {result}")
        print("空仓库已初始化（种子文件，不触发 Actions）")

    # 2) 每个文件建 blob（二进制 PNG 也走 base64）
    tree = []
    for index, rel in enumerate(files, 1):
        content = base64.b64encode((ROOT / rel).read_bytes()).decode()
        code, result = req(
            "POST", f"{BASE}/git/blobs",
            {"content": content, "encoding": "base64"},
        )
        if code not in (200, 201) or "sha" not in result:
            sys.exit(f"blob 失败 [{rel}] HTTP {code}: {result}")
        tree.append({"path": rel, "mode": "100644", "type": "blob", "sha": result["sha"]})
        if index % 5 == 0 or index == len(files):
            print(f"  blob {index}/{len(files)}")

    # 3) tree
    code, result = req("POST", f"{BASE}/git/trees", {"tree": tree})
    if code not in (200, 201):
        sys.exit(f"建 tree 失败 HTTP {code}: {result}")
    tree_sha = result["sha"]

    # 4) commit（空仓库无 parent；已有 main 则接在后面）
    code, ref = req("GET", f"{BASE}/git/ref/heads/main")
    parents = [ref["object"]["sha"]] if code == 200 and "object" in ref else []
    code, result = req(
        "POST", f"{BASE}/git/commits",
        {"message": "feat(v0.3): ADB 自动化骨架（发现/AUTH/sync push/命令状态机）+ 全自动监听接收",
         "tree": tree_sha, "parents": parents},
    )
    if code not in (200, 201):
        sys.exit(f"建 commit 失败 HTTP {code}: {result}")
    commit_sha = result["sha"]

    # 5) 创建或强制更新 main 引用
    if parents:
        code, result = req(
            "PATCH", f"{BASE}/git/refs/heads/main",
            {"sha": commit_sha, "force": True},
        )
        action = "更新"
    else:
        code, result = req(
            "POST", f"{BASE}/git/refs",
            {"ref": "refs/heads/main", "sha": commit_sha},
        )
        action = "创建"
    if code not in (200, 201):
        sys.exit(f"{action} main 失败 HTTP {code}: {result}")

    # 6) 确保默认分支是 main（否则 on: push branches:[main] 不触发）
    req("PATCH", BASE, {"default_branch": "main"})

    # 把本次 commit sha 落盘，供 cloud_build.sh 精确匹配对应的 Actions run
    # （GitHub runs 列表有延迟，用 per_page=1 会误读到上一次的旧 run）
    sha_file = ROOT / ".last_commit_sha"
    sha_file.write_text(commit_sha)
    print(f"已{action} main: {commit_sha[:12]}（{len(files)} 个文件，单次提交）")


if __name__ == "__main__":
    main()
