#!/usr/bin/env bash
set -euo pipefail

# 定义颜色
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# 定义脚本目录
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_DIR="$BASE_DIR/../Scripts"

echo "===== 开始执行脚本任务 ====="

echo -e "${PURPLE}[00] 运行前置整理${NC}"
bash "$SCRIPT_DIR/00_targets_classify.sh"

echo -e "${PURPLE}[1/3] IP 端口扫描${NC}"
bash "$SCRIPT_DIR/01_discover_rustscan.sh"
bash "$SCRIPT_DIR/02_nmap_svcid.sh"

echo -e "${PURPLE}[2/3] 运行 Subfinder 子域名收集...${NC}"
bash "$SCRIPT_DIR/02_subfinder.sh"

echo -e "${PURPLE}[3/3] 运行 Ehole 魔改扫描...${NC}"
bash "$SCRIPT_DIR/03_ehole_web_scan.sh"

echo "===== 所有脚本执行完成 ====="
