#!/usr/bin/env bash
set -euo pipefail

# 定义颜色变量
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 硬编码目标域名和目标文件
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
TARGET="${SCRIPT_DIR}/../TargetInput/TargetClassification/subdomains.txt"
DOMAIN="${SCRIPT_DIR}/../TargetInput/TargetClassification/domains.txt"
SCRIPT_FILE="${SCRIPT_DIR}/../Tools/Subfinder/subfinder"
TMP_OUTPUT="$(mktemp)"
TMP_TARGET_SORTED="$(mktemp)"
trap 'rm -f "$TMP_OUTPUT" "$TMP_TARGET_SORTED"' EXIT

# 硬编码 subfinder 语句，只输出子域名
$SCRIPT_FILE -dL "$DOMAIN" -silent >"$TMP_OUTPUT" 2>/dev/null || true

# 如果没结果直接退出
if [[ ! -s "$TMP_OUTPUT" ]]; then
  echo -e "${RED}没有发现子域${NC}"
  exit 0
fi

# 目标文件去重
sort -u "$TARGET" >"$TMP_TARGET_SORTED"

# 找到新增子域
NEW_LINES="$(comm -23 <(sort -u "$TMP_OUTPUT") "$TMP_TARGET_SORTED" || true)"

if [[ -n "$NEW_LINES" ]]; then
  echo -e "${YELLOW}$NEW_LINES${NC}" >> "$TARGET"
  echo -e "${GREEN}已追加 $(echo "$NEW_LINES" | wc -l) 个新子域到 $TARGET${NC}"
else
  echo -e "${GREEN}没有新增子域${NC}"
fi
