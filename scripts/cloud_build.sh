#!/usr/bin/env bash
# 一键云端编译：复用独立空仓库 → push → 等 macOS runner 编译 → 取回 .ipa
#
# 用法（令牌由外部注入，脚本不打印、不落盘）:
#   export GITHUB_TOKEN=<token>; ./scripts/cloud_build.sh
# 可选: REPO_NAME=FusionRecorder-iOS（默认） / POLL_TIMEOUT=1200（秒）
set -euo pipefail

: "${GITHUB_TOKEN:?请先 export GITHUB_TOKEN=...（需要对目标仓库 push + actions 写权限）}"

REPO="${REPO_NAME:-FusionRecorder-iOS}"
POLL_TIMEOUT="${POLL_TIMEOUT:-1200}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
API="https://api.github.com"
PY="${PYTHON:-python3}"

say() { printf '\n==> %s\n' "$*"; }
auth() { curl -sS -H "Authorization: Bearer $GITHUB_TOKEN" -H "Accept: application/vnd.github+json" "$@"; }
# 供需要多参数 curl 的场景（下载 run 日志 zip）复用同一组认证头
CURL_AUTH=(-H "Authorization: Bearer $GITHUB_TOKEN" -H "Accept: application/vnd.github+json")

say "读取 GitHub 账号"
OWNER=$(auth "$API/user" | "$PY" -c 'import sys,json; print(json.load(sys.stdin).get("login") or "")')
if [ -z "$OWNER" ]; then echo "!! 无法读取账号，检查令牌是否有效"; exit 1; fi
echo "账号: $OWNER / 仓库: $REPO（独立仓库，不触碰其他任何应用）"

say "检查独立仓库 $OWNER/$REPO"
# 用带令牌的请求查：匿名 API 有独立限流，限流时会把已存在的仓库误判成「不存在」
CHECK=$(auth -o /tmp/fusion_repo_check.json -w "%{http_code}" "$API/repos/$OWNER/$REPO")
echo "仓库检查 HTTP $CHECK"
case "$CHECK" in
  200)
    "$PY" - <<'PY'
import json
d = json.load(open('/tmp/fusion_repo_check.json'))
p = d.get('permissions') or {}
print('  空仓库:', d.get('size') == 0, '| 默认分支:', d.get('default_branch'),
      '| push 权限:', p.get('push'), '| admin:', p.get('admin'))
PY
    ;;
  404)
    echo "仓库不存在，尝试用令牌创建"
    CODE=$(auth -o /tmp/fusion_repo.json -w "%{http_code}" -X POST \
      "$API/user/repos" \
      -d "{\"name\":\"$REPO\",\"description\":\"融合录屏 iPhone 端（独立仓库）\",\"private\":false,\"auto_init\":false}")
    case "$CODE" in
      201) echo "已创建 $OWNER/$REPO" ;;
      422) echo "仓库已存在，复用 $OWNER/$REPO" ;;
      403) echo "!! 令牌无创建仓库权限。请在 https://github.com/new 手动创建空的公开仓库 $REPO（不勾 README/.gitignore/LICENSE）"; exit 1 ;;
      *)   echo "!! 创建失败 HTTP $CODE"; cat /tmp/fusion_repo.json; exit 1 ;;
    esac
    ;;
  *) echo "!! 仓库检查失败 HTTP $CHECK"; cat /tmp/fusion_repo_check.json; exit 1 ;;
esac

say "推送 main（走 REST Git Data API，一次提交只触发一次构建）"
cd "$ROOT"
git init -q
git symbolic-ref HEAD refs/heads/main
# 只设本仓库身份，不污染全局 git config
git config user.name "${GIT_AUTHOR_NAME:-WorkBuddy}"
git config user.email "${GIT_AUTHOR_EMAIL:-workbuddy@users.noreply.github.com}"
git add -A
git commit -qm "feat: FusionRecorder-iOS v0.2 工程 + 云端编译 workflow" || echo "(内容无变化)"
# 沙箱里 github.com:443 的 git smart HTTP 不可达，改用 api.github.com
"$PY" scripts/push_via_api.py "$OWNER" "$REPO" "$ROOT"

say "确认 workflow 已被触发（按本次 commit sha 精确匹配，避免误读旧 run）"
TARGET_SHA="$(cat "$ROOT/.last_commit_sha" 2>/dev/null || echo "")"
if [ -z "$TARGET_SHA" ]; then echo "!! 读不到本次 commit sha"; exit 1; fi
echo "目标 commit: ${TARGET_SHA:0:12}"

# 找到 head_sha == TARGET_SHA 的 run；runs 列表有延迟，最多等 120s
RUN_ID=""
WAITED=0
while [ "$WAITED" -lt 120 ]; do
  RUN_ID=$(auth "$API/repos/$OWNER/$REPO/actions/runs?per_page=10" | "$PY" -c '
import sys, json
target = sys.argv[1]
try:
    runs = json.load(sys.stdin).get("workflow_runs", [])
except Exception:
    runs = []
for r in runs:
    if r.get("head_sha") == target:
        print(r["id"]); break
' "$TARGET_SHA" 2>/dev/null || echo "")
  if [ -n "$RUN_ID" ]; then echo "已检测到本次 commit 的 run: $RUN_ID（等待 ${WAITED}s）"; break; fi
  sleep 10; WAITED=$((WAITED + 10))
done
if [ -z "$RUN_ID" ]; then
  echo "push 未触发 run，尝试 workflow_dispatch 后重新匹配"
  DC=$(auth -o /tmp/fusion_dispatch.json -w "%{http_code}" -X POST \
    -H "Content-Type: application/json" \
    "$API/repos/$OWNER/$REPO/actions/workflows/build-ipa.yml/dispatches" \
    -d "{\"ref\":\"main\"}")
  echo "dispatch HTTP $DC"
  [ "$DC" != "204" ] && { echo "!! dispatch 失败（HTTP $DC）"; cat /tmp/fusion_dispatch.json; exit 1; }
  WAITED=0
  while [ "$WAITED" -lt 120 ]; do
    RUN_ID=$(auth "$API/repos/$OWNER/$REPO/actions/runs?per_page=10" | "$PY" -c '
import sys, json
target = sys.argv[1]
try: runs = json.load(sys.stdin).get("workflow_runs", [])
except Exception: runs = []
for r in runs:
    if r.get("head_sha") == target:
        print(r["id"]); break
' "$TARGET_SHA" 2>/dev/null || echo "")
    [ -n "$RUN_ID" ] && { echo "dispatch 后检测到 run: $RUN_ID"; break; }
    sleep 10; WAITED=$((WAITED + 10))
  done
  [ -z "$RUN_ID" ] && { echo "!! 仍找不到本次 commit 的 run"; exit 1; }
fi

say "等待 GitHub Actions 编译（最长 ${POLL_TIMEOUT}s）"
DEADLINE=$(( $(date +%s) + POLL_TIMEOUT ))
LAST=""
FINISHED=0
while [ "$(date +%s)" -lt "$DEADLINE" ]; do
  # 直接查本次 run，绝不读 runs?per_page=1（会拿到旧 run 的过期状态/错误）
  RESP=$(auth "$API/repos/$OWNER/$REPO/actions/runs/$RUN_ID")
  STATE=$(printf '%s' "$RESP" | "$PY" -c '
import sys, json
d = json.load(sys.stdin)
print("%s|%s|%s|%s" % (d.get("status"), d.get("conclusion") or "pending", d.get("id"), d.get("head_sha","")[:8]))
' 2>/dev/null || echo "waiting|parse-error|0|")
  if [ "$STATE" != "$LAST" ]; then echo "  状态: $STATE"; LAST="$STATE"; fi
  STATUS="${STATE%%|*}"; REST="${STATE#*|}"; CONCLUSION="${REST%%|*}"
  if [ "$STATUS" = "completed" ]; then
    FINISHED=1
    if [ "$CONCLUSION" = "success" ]; then echo "云端编译成功"; break; fi
    echo "!! 构建失败 ($CONCLUSION)"
    echo "   从本次 run 的真实日志提取错误（不用 ios-build 上可能过期的 errors.txt）："
    cd /tmp && rm -rf fusion_run_logs && mkdir fusion_run_logs && cd fusion_run_logs
    curl -sSL "${CURL_AUTH[@]}" -o logs.zip "$API/repos/$OWNER/$REPO/actions/runs/$RUN_ID/logs" 2>/dev/null || true
    unzip -q -o logs.zip 2>/dev/null || true
    grep -rhE "error:|BUILD FAILED" . 2>/dev/null | grep -v "grep -E" | sort -u | head -30 || true
    cd "$ROOT"
    echo "完整日志: https://github.com/$OWNER/$REPO/actions/runs/$RUN_ID"
    exit 1
  fi
  sleep 15
done
if [ "$FINISHED" != "1" ]; then echo "!! 等待超时，未拿到构建结果"; exit 1; fi

say "取回构建日志与 .ipa"
VER=$(sed -n 's/^ *MARKETING_VERSION: *"\([^"]*\)".*/\1/p' project.yml | head -1)
mkdir -p ci-logs
RAW="https://raw.githubusercontent.com/$OWNER/$REPO/ios-build/ci-logs"
curl -sSL -o ci-logs/last-build.md "$RAW/last-build.md" || true
curl -sSL -o "ci-logs/FusionRecorder-$VER-unsigned.ipa" "$RAW/FusionRecorder-$VER-unsigned.ipa"
FILE="ci-logs/FusionRecorder-$VER-unsigned.ipa"
if [ ! -s "$FILE" ] || ! unzip -t "$FILE" >/dev/null 2>&1; then
  echo "!! IPA 下载失败或不是有效 zip，见 $RAW/FusionRecorder-$VER-unsigned.ipa"
  echo "   也可到 https://github.com/$OWNER/$REPO/actions 下载 artifact"
  exit 1
fi
ls -lh "$FILE"
echo "完成：$ROOT/$FILE"
echo "侧载源：https://raw.githubusercontent.com/$OWNER/$REPO/ios-build/ci-logs/source.json"
