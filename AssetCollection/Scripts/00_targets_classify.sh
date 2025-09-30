#!/usr/bin/env bash
set -euo pipefail

# 定义颜色变量
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

# 获取脚本目录
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
SCRIPT_PATH="$SCRIPT_DIR/$(basename "${BASH_SOURCE[0]}")"

# 运行 Python 脚本
PYTHON_SCRIPT="$SCRIPT_DIR/PythonScript/classify_targets_strict.py"

# 检查 Python 脚本是否存在
if [[ -f "$PYTHON_SCRIPT" ]]; then
    echo -e "   ${GREEN}资产分类脚本 runing ${NC}"
    python3 "$PYTHON_SCRIPT"
else
    echo -e "   ${RED}错误: 找不到 Python 资产分类脚本: $PYTHON_SCRIPT${NC}"
    exit 1
fi
