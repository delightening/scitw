#!/usr/bin/env bash
# 更新 /latest 指向最新一期月報，並自動 commit + push。
#
# 用法：
#   scripts/publish-latest.sh                       # 自動找 Briefings/ 下檔名最大者
#   scripts/publish-latest.sh <path/to/file.html>   # 指定特定檔案
#
# 前置：新的 HTML 已放到 Briefings/ 下（命名如 科學人新知月報YYYYMM.html）

set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
cd "$REPO_ROOT"

if [ $# -ge 1 ]; then
  TARGET="$1"
else
  # 依檔名排序取最後一個（命名含 YYYYMM 時即為最新）
  TARGET=$(find Briefings -type f -name "*.html" | sort | tail -n1)
fi

if [ -z "${TARGET:-}" ] || [ ! -f "$TARGET" ]; then
  echo "錯誤：找不到 HTML 檔案：${TARGET:-<empty>}" >&2
  exit 1
fi

# 若 HTML 尚未包含 nav，則在 <body> 之後注入
SNIPPET="scripts/nav-snippet.html"
if [ -f "$SNIPPET" ] && ! grep -q 'scitw-nav:start' "$TARGET"; then
  sed -i '/<body[^>]*>/r '"$SNIPPET" "$TARGET"
  echo "  已注入 nav → $TARGET"
fi

# 寫入 _redirects
printf "/latest   /%s   302\n" "$TARGET" > _redirects

# 從檔名抓 YYYYMM 做 commit message
MONTH=$(basename "$TARGET" .html | grep -oE '[0-9]{6}' | tail -n1 || true)
if [ -n "$MONTH" ]; then
  MSG="chore: /latest → ${MONTH} 月報"
else
  MSG="chore: 更新 /latest → $(basename "$TARGET")"
fi

git add -- _redirects "$TARGET"

if git diff --cached --quiet; then
  echo "沒有變更可 commit。"
  exit 0
fi

git commit -m "$MSG"
git push

echo "✓ 已 push：$TARGET"
echo "  Cloudflare Pages 約 30 秒後生效：/latest"
