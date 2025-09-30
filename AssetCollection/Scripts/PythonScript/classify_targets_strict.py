#!/usr/bin/env python3
# -*- coding: utf-8 -*-
import os
import re
import ipaddress

# 输入文件
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__));
INPUT_FILE = SCRIPT_DIR + "/../../TargetInput/targets.txt"
OUTPUT_DIR = SCRIPT_DIR + "/../../TargetInput/TargetClassification"

# 输出文件
FILES = {
    "ips": "ips.txt",
    "host_with_port": "host_with_port.txt",
    "domains": "domains.txt",
    "subdomains": "subdomains.txt",
    "urls": "urls.txt",
    "unresolved": "unresolved.txt"
}

# 确保输出目录存在
os.makedirs(OUTPUT_DIR, exist_ok=True)

# 清空旧文件
for f in FILES.values():
    open(os.path.join(OUTPUT_DIR, f), "w").close()


def is_ip(s: str) -> bool:
    try:
        ipaddress.ip_address(s)
        return True
    except ValueError:
        return False


def expand_ip_range(s: str):
    """识别 192.168.1.1-24 形式的 IP 段"""
    m = re.match(r"^(\d{1,3}\.\d{1,3}\.\d{1,3})\.(\d{1,3})-(\d{1,3})$", s)
    if not m:
        return []
    base, start, end = m.groups()
    start, end = int(start), int(end)
    if start > end or start < 0 or end > 255:
        return []
    return [f"{base}.{i}" for i in range(start, end + 1)]


def expand_cidr(s: str):
    """识别并展开 CIDR 段，如 192.168.25.0/24"""
    try:
        net = ipaddress.ip_network(s, strict=False)
        return [str(ip) for ip in net.hosts()]
    except ValueError:
        return []


def classify_line(line: str):
    """分类规则"""
    line = line.strip()
    if not line:
        return "unresolved", [line]

    # URL 检查
    if line.startswith("http://") or line.startswith("https://"):
        return "urls", [line]

    # IP:Port
    if re.match(r"^\d{1,3}(\.\d{1,3}){3}:\d{1,5}$", line):
        return "host_with_port", [line]

    # 域名:Port
    if re.match(r"^(?:[a-zA-Z0-9-]+\.)+[a-zA-Z]{2,}:\d{1,5}$", line):
        return "host_with_port", [line]

    # IP 段（192.168.1.1-24）
    expanded = expand_ip_range(line)
    if expanded:
        return "ips", expanded

    # CIDR
    expanded = expand_cidr(line)
    if expanded:
        return "ips", expanded

    # 纯 IP
    if is_ip(line):
        return "ips", [line]

    # 域名
    domain_pattern = re.compile(r"^(?:[a-zA-Z0-9-]+\.)+[a-zA-Z]{2,}$")
    if domain_pattern.match(line):
        parts = line.split(".")
        if len(parts) == 2:  # 二级域名
            return "domains", [line]
        elif len(parts) >= 3:  # 三级及以上
            return "subdomains", [line]

    return "unresolved", [line]


def main():
    with open(INPUT_FILE, "r", encoding="utf-8") as infile:
        for line in infile:
            line = line.strip()
            category, results = classify_line(line)
            with open(os.path.join(OUTPUT_DIR, FILES[category]), "a", encoding="utf-8") as f:
                for item in results:
                    if item:  # 避免空行
                        f.write(item + "\n")


if __name__ == "__main__":
    main()
    print(f"   运行结束! \n   分类完成，结果已保存至 TargetInput/TargetClassification/ 下\n")
