#!/usr/bin/env bash
set -euo pipefail

# 定义颜色变量
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
INPUT_FILE="${SCRIPT_DIR}/../ProcessOutputResults/01_rustscanResult.txt"
OUT_DIR="${SCRIPT_DIR}/../ProcessOutputResults/02_nmap"
PER_HOST_DIR="${OUT_DIR}/per_host"
ALL_IPS_FILE="${OUT_DIR}/all_ips.txt"
TXT_OUT="${OUT_DIR}/all_hosts.txt"
# 目标文件（按你的要求）
TARGET_FILE="${SCRIPT_DIR}/../TargetInput/TargetClassification/host_with_port.txt"
LOGDIR="${OUT_DIR}/logs"
LOGFILE="${OUT_DIR}/nmap.txt"
NMAP_BIN="${NMAP_BIN:-nmap}"

# 并发与超时配置
NMAP_PARALLEL="${NMAP_PARALLEL:-6}"
NMAP_TIMEOUT="${NMAP_TIMEOUT:-600}"

mkdir -p "$OUT_DIR" "$PER_HOST_DIR" "$LOGDIR"
# 确保目标目录存在
mkdir -p "$(dirname "$TARGET_FILE")"

# helper: sanitize filename
sanitize_name() {
  local s="$1"
  s="${s//:/_}"
  s="${s//\//_}"
  s="${s//\[/_}"
  s="${s//\]/_}"
  s="${s// /_}"
  s="${s//%/_}"
  echo "$s"
}

# 运行单个 nmap 的函数：ip, ports(comma separated)
run_nmap_job() {
  local ip="$1"
  local ports="$2"
  local safeip
  safeip="$(sanitize_name "$ip")"
  local outfile="${PER_HOST_DIR}/${safeip}.txt"

  echo -e "${YELLOW} INFO: START! --> $outfile${NC}"

  if command -v timeout >/dev/null 2>&1; then
    timeout "${NMAP_TIMEOUT}s" "$NMAP_BIN" -sV -Pn --version-all -p "$ports" "$ip" -oN "$outfile" >>"$LOGFILE" 2>&1 || {
      echo -e "${RED} WARN: nmap exit non-zero for $ip ports=$ports${NC}"
    }
  else
    "$NMAP_BIN" -sV -Pn --version-all -p "$ports" "$ip" -oN "$outfile" >>"$LOGFILE" 2>&1 || {
      echo -e "${RED} WARN: nmap exit non-zero for $ip ports=$ports${NC}" 
    }
  fi

  echo -e "${YELLOW} INFO: OK! --> $outfile${NC}" 
}

# 并发控制
pids=()
wait_for_slot() {
  local new_pids=()
  for pid in "${pids[@]:-}"; do
    if kill -0 "$pid" 2>/dev/null; then
      new_pids+=("$pid")
    else
      wait "$pid" 2>/dev/null || true
    fi
  done
  pids=("${new_pids[@]}")
  while [ "${#pids[@]}" -ge "$NMAP_PARALLEL" ]; do
    sleep 0.2
    local refreshed=()
    for pid in "${pids[@]:-}"; do
      if kill -0 "$pid" 2>/dev/null; then
        refreshed+=("$pid")
      else
        wait "$pid" 2>/dev/null || true
      fi
    done
    pids=("${refreshed[@]}")
  done
}

# STEP 1: 解析输入
: > "$PER_HOST_DIR/.tmp_ip_ports"
: > "$ALL_IPS_FILE"

while IFS= read -r line || [ -n "$line" ]; do
  line="${line%%$'\r'}"
  line="$(echo "$line" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')"
  [ -z "$line" ] && continue
  case "$line" in
    \#*) continue ;;
  esac

  ip=$(echo "$line" | sed -n 's/^\s*\([^ ]\+\)\s*->.*$/\1/p')
  ports_raw=$(echo "$line" | sed -n 's/.*\[\(.*\)\].*/\1/p')

  if [ -z "$ip" ] || [ -z "$ports_raw" ]; then
    echo -e "${RED} WARN: cannot parse line: $line${NC}" 
    continue
  fi

  ports=$(echo "$ports_raw" | tr -d '[:space:]' | sed 's/,$//')
  if echo "$ports" | grep -Eqv '^([0-9]+,?)+$'; then
    echo -e "${RED} WARN: invalid ports for $ip: $ports_raw${NC}"
    continue
  fi

  echo "$ip" >> "$ALL_IPS_FILE"
  echo "${ip}|${ports}" >> "${PER_HOST_DIR}/.tmp_ip_ports"
done < "$INPUT_FILE"

echo -e "${YELLOW} INFO: extracted ip_ports -> ${PER_HOST_DIR}/.tmp_ip_ports;${NC}"
echo -e "${YELLOW} INFO: all_ips -> $ALL_IPS_FILE${NC}"

# STEP 2: 运行 nmap
while IFS= read -r entry || [ -n "$entry" ]; do
  ip=$(echo "$entry" | cut -d'|' -f1)
  ports=$(echo "$entry" | cut -d'|' -f2)

  wait_for_slot
  run_nmap_job "$ip" "$ports" &
  pids+=($!)
done < "${PER_HOST_DIR}/.tmp_ip_ports"

for pid in "${pids[@]:-}"; do
  wait "$pid" || true
done

echo -e "${YELLOW} INFO: all per-host nmap jobs finished${NC}"

# STEP 3: 合并所有 txt 文件（保留原始内容）
echo -e "${YELLOW} INFO: merging per-host txt into $TXT_OUT${NC}"
: > "$TXT_OUT"

shopt -s nullglob
for f in "$PER_HOST_DIR"/*.txt; do
  echo "===== $f =====" >> "$TXT_OUT"
  cat "$f" >> "$TXT_OUT"
  echo "" >> "$TXT_OUT"
done

# ========================= STEP 4: 提取 IP:PORT =========================

echo -e "${YELLOW} INFO: extracting open TCP ports to $TARGET_FILE${NC}"

TMP_NEW="$(mktemp "${TARGET_FILE}.new.XXXXXX")"
: > "$TMP_NEW"

for f in "$PER_HOST_DIR"/*.txt; do
    # 1) 提取扫描目标 IP（优先括号内 IP，否则取目标 IP）
    ip="$(grep -m1 '^Nmap scan report for' "$f" 2>/dev/null \
        | sed -E 's/^Nmap scan report for .* \(([^)]+)\).*/\1/; t; s/^Nmap scan report for ([^ ]+).*/\1/')"

    # 校验合法 IP（IPv4 或 IPv6）
    if ! echo "$ip" | grep -Eq '^([0-9]{1,3}\.){3}[0-9]{1,3}$|^[0-9a-fA-F:]+$'; then
        echo -e "${RED} WARN: skip invalid IP from $f -> $ip${NC}" 
        continue
    fi

    # 2) 提取所有 open TCP 端口
    awk '/\/tcp/ && /open/ { split($1,a,"/"); print a[1] }' "$f" | while read -r port; do
        # 跳过空行
        [ -z "$port" ] && continue
        echo "${ip}:${port}" >> "$TMP_NEW"
    done
done

# 3) 确保目标文件存在
touch "$TARGET_FILE"

# 4) 追加新 IP:PORT，避免重复
if [ ! -s "$TARGET_FILE" ]; then
    # 文件为空，直接追加全部
    cat "$TMP_NEW" >> "$TARGET_FILE"
    echo -e "${YELLOW} INFO: appended $(wc -l < "$TMP_NEW") entries to $TARGET_FILE${NC}"
else
    # 文件非空，只追加不重复的新行
    new_count=0
    while IFS= read -r line; do
        [ -z "$line" ] && continue
        if ! grep -Fqx -- "$line" "$TARGET_FILE"; then
            echo "$line" >> "$TARGET_FILE"
            new_count=$((new_count+1))
        fi
    done < "$TMP_NEW"
    echo -e "${YELLOW} INFO: appended $new_count new entries to $TARGET_FILE${NC}"
fi

# 清理临时文件
rm -f "$TMP_NEW"

echo -e "${YELLOW} Nmap Scan DONE.${NC}"

