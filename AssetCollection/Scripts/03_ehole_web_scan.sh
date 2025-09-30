#!/usr/bin/env bash
set -euo pipefail

# 定义颜色变量
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
SubdomainsINPUT_FILE="${SCRIPT_DIR}/../TargetInput/TargetClassification/subdomains.txt"
EHOLE_DIR="${SCRIPT_DIR}/../Tools/Ehole/ehole_linux"
UrlsINPUT_FILE="${SCRIPT_DIR}/../TargetInput/TargetClassification/urls.txt"
Host_with_portINPUT_FILE="${SCRIPT_DIR}/../TargetInput/TargetClassification/host_with_port.txt"
OUTPUT_FILE="${EHOLE_DIR}/../../../ProcessOutputResults/03_ehole.xlsx"
SCRIPT_FILE="${SCRIPT_DIR}/../Tools/Ehole/ehole_linux/ehole_linux"
mkdir -p "$(dirname "$OUTPUT_FILE")"

TMP_FILE=$(mktemp)

# 处理 subdomains.txt -> 拼接 http/https
if [[ -f "$SubdomainsINPUT_FILE" ]]; then
    awk '{print "http://"$0; print "https://"$0}' "$SubdomainsINPUT_FILE" >> "$TMP_FILE"
fi

# 处理 host_with_port.txt -> 拼接 http/https
if [[ -f "$Host_with_portINPUT_FILE" ]]; then
    awk '{print "http://"$0; print "https://"$0}' "$Host_with_portINPUT_FILE" >> "$TMP_FILE"
fi

# 处理 urls.txt -> 直接使用
if [[ -f "$UrlsINPUT_FILE" ]]; then
    cat "$UrlsINPUT_FILE" >> "$TMP_FILE"
fi

# 去重
sort -u "$TMP_FILE" -o "$TMP_FILE"

# 在 EHOLE_DIR 工作目录下执行 ehole（确保能找到 poc.ini 等相对资源）
(
  cd "$EHOLE_DIR" || { echo "[ERROR] 无法进入目录: $EHOLE_DIR" >&2; exit 3; }
  # 如果 ehole 支持通过 -l 指定输入文件，这里直接传入 TMP_FILE
  "$SCRIPT_FILE" finger -l "$TMP_FILE" -o  -t 5 | tee "$OUTPUT_FILE" || true
)

rm "$TMP_FILE"
echo -e "${GREEN}\n[+] 探测完成，结果已保存到: $OUTPUT_FILE${NC}"

