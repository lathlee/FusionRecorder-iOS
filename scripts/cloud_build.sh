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

say "确认 workflow 已被触发（没有则手动 dispatch 兜底）"
RUNS="$API/repos/$OWNER/$REPO/actions/runs?per_page=1"
WAITED=0
while [ "$WAITED" -lt 90 ]; do
  N=$(auth "$RUNS" | "$PY" -c 'import sys,json; print(len(json.load(sys.stdin).get("workflow_runs",[])))' 2>/dev/null || echo 0)
  if [ "$N" != "0" ] && [ -n "$N" ]; then echo "已检测到 workflow run（等待 ${WAITED}s）"; break; fi
  sleep 10; WAITED=$((WAITED + 10))
done
if [ "${N:-0}" = "0" ] || [ -z "${N:-}" ]; then
  echo "未检测到 push 触发的 run，尝试 workflow_dispatch"
  DC=$(auth -o /tmp/fusion_dispatch.json -w "%{http_code}" -X POST \
    -H "Content-Type: application/json" \
    "$API/repos/$OWNER/$REPO/actions/workflows/build-ipa.yml/dispatches" \
    -d '{"ref":"main"}')
  echo "dispatch HTTP $DC"
  if [ "$DC" != "204" ]; then
    echo "!! 既没有 push 触发、dispatch 也失败（HTTP $DC）"; cat /tmp/fusion_dispatch.json
    echo "   请在仓库页面手动 Run workflow：https://github.com/$OWNER/$REPO/actions/workflows/build-ipa.yml"
    exit 1
  fi
fi

say "等待 GitHub Actions 编译（最长 ${POLL_TIMEOUT}s）"
DEADLINE=$(( $(date +%s) + POLL_TIMEOUT ))
LAST=""
FINISHED=0
while [ "$(date +%s)" -lt "$DEADLINE" ]; do
  RESP=$(auth "$RUNS")
  STATE=$(printf '%s' "$RESP" | "$PY" -c '
import sys, json
d = json.load(sys.stdin)
runs = d.get("workflow_runs", [])
if not runs:
    print("waiting|no-run|0|")
else:
    r = runs[0]
    print("%s|%s|%s|%s" % (r.get("status"), r.get("conclusion") or "pending", r.get("id"), r.get("head_sha","")[:8]))
' 2>/dev/null || echo "waiting|parse-error|0|")
  if [ "$STATE" != "$LAST" ]; then echo "  状态: $STATE"; LAST="$STATE"; fi
  STATUS="${STATE%%|*}"; REST="${STATE#*|}"; CONCLUSION="${REST%%|*}"
  if [ "$STATUS" = "completed" ]; then
    FINISHED=1
    if [ "$CONCLUSION" = "success" ]; then echo "云端编译成功"; break; fi
    echo "!! 构建失败 ($CONCLUSION)，错误摘要："
    curl -sS "https://raw.githubusercontent.com/$OWNER/$REPO/ios-build/ci-logs/errors.txt" | head -60 || true
    echo
    RUNID=$(printf '%s' "$STATE" | cut -d'|' -f3)
    echo "完整日志: https://github.com/$OWNER/$REPO/actions/runs/$RUNID"
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
