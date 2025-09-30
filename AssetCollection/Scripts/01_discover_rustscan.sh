#!/usr/bin/env bash

# 定义颜色变量
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
RUSTSCAN_BIN="$SCRIPT_DIR/../Tools/RustScan/rustscan"
INPUT="$SCRIPT_DIR/../TargetInput/TargetClassification/ips.txt"
OUT="$SCRIPT_DIR/../ProcessOutputResults/01_rustscanResult.txt"

# 检查 RustScan 是否存在
if [[ ! -f "$RUSTSCAN_BIN" ]]; then
    echo -e "   ${RED}错误: 未找到 RustScan!${NC}"
    echo -e "   ${RED}记录目录为:  ${NC}"
    echo -e "   ${RED}$RUSTSCAN_BIN${NC}"
    exit 1
fi

echo -e "   ${YELLOW}RustScan running${NC}"
# RustScan: 扫描目标
# -a "$(paste -sd, $INPUT)" ：paste -sd 命令会将 $INPUT 文件中的多行内容合并成一行，并用逗号 , 分隔
# -b 4000 ：设置端口扫描的并发连接数（batch size）
# -t 2500 ：设置超时时间（毫秒）。如果一个端口在 3000 毫秒（3 秒）内没有响应，则视为超时
# --ulimit 50000：尝试设置系统的文件描述符限制（ulimit -n）
# 使用 grepable 模式运行 RustScan
# 先显示在控制台，同时保存到文件
echo -e "   ${YELLOW}实时扫描结果:${NC}"
stdbuf -oL "$RUSTSCAN_BIN" -a "$(paste -sd, "$INPUT")" -b 10000 -t 2500 --ulimit 20000 -g | tee "$OUT" || true
echo -e "   ${YELLOW}RustScan DISCOVERED 已输出至 ProcessOutputResults 目录下 ${NC}"
