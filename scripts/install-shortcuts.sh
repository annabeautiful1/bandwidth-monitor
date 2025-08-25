#!/bin/bash
# 安装 Bandwidth Monitor 简化命令
# 创建 bm, status bm, log bm, restart bm 等命令

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

require_root() {
  if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}请使用 sudo 或 root 运行本脚本${NC}" >&2
    exit 1
  fi
}

log_success() {
  echo -e "${GREEN}[成功]${NC} $1"
}

log_info() {
  echo -e "${CYAN}[信息]${NC} $1"
}

require_root

# 创建 bm 命令（主控制脚本）
cat > /usr/local/bin/bm << 'EOF'
#!/bin/bash
# Bandwidth Monitor 快捷命令

if [[ $EUID -ne 0 ]]; then
  echo -e "\033[0;31m请使用 sudo 运行本命令\033[0m" >&2
  exit 1
fi

REPO="annabeautiful1/bandwidth-monitor"
RAW_BASE_GH="https://raw.githubusercontent.com/${REPO}/main"
RAW_PROXY="https://ghfast.top/"

bash <(curl -sSL "${RAW_PROXY}${RAW_BASE_GH}/scripts/bmctl.sh")
EOF

# 创建 status 命令
cat > /usr/local/bin/status << 'EOF'
#!/bin/bash
# 查看服务状态快捷命令

case "$1" in
  bm|bandwidth-monitor)
    echo "=== 服务端状态 ==="
    systemctl status bandwidth-monitor --no-pager -l 2>/dev/null || echo "服务端未安装"
    echo
    echo "=== 客户端状态 ==="
    systemctl status bandwidth-monitor-client --no-pager -l 2>/dev/null || echo "客户端未安装"
    ;;
  *)
    echo "用法: status bm"
    echo "显示 Bandwidth Monitor 服务状态"
    exit 1
    ;;
esac
EOF

# 创建 log 命令
cat > /usr/local/bin/log << 'EOF'
#!/bin/bash
# 查看日志快捷命令

case "$1" in
  bm|bandwidth-monitor)
    echo "选择要查看的日志:"
    echo "1) 服务端日志"
    echo "2) 客户端日志"
    read -rp "选择 [1-2]: " choice
    case "$choice" in
      1) journalctl -u bandwidth-monitor -n 50 --no-pager -f;;
      2) journalctl -u bandwidth-monitor-client -n 50 --no-pager -f;;
      *) echo "无效选择";;
    esac
    ;;
  *)
    echo "用法: log bm"
    echo "查看 Bandwidth Monitor 日志"
    exit 1
    ;;
esac
EOF

# 创建 restart 命令
cat > /usr/local/bin/restart << 'EOF'
#!/bin/bash
# 重启服务快捷命令

if [[ $EUID -ne 0 ]]; then
  echo -e "\033[0;31m请使用 sudo 运行本命令\033[0m" >&2
  exit 1
fi

case "$1" in
  bm|bandwidth-monitor)
    echo "选择要重启的服务:"
    echo "1) 服务端"
    echo "2) 客户端"
    echo "3) 全部"
    read -rp "选择 [1-3]: " choice
    case "$choice" in
      1) 
        echo "重启服务端..."
        systemctl restart bandwidth-monitor 2>/dev/null && echo -e "\033[0;32m服务端重启完成\033[0m" || echo -e "\033[0;31m服务端重启失败\033[0m"
        systemctl status bandwidth-monitor --no-pager -l
        ;;
      2) 
        echo "重启客户端..."
        systemctl restart bandwidth-monitor-client 2>/dev/null && echo -e "\033[0;32m客户端重启完成\033[0m" || echo -e "\033[0;31m客户端重启失败\033[0m"
        systemctl status bandwidth-monitor-client --no-pager -l
        ;;
      3)
        echo "重启全部服务..."
        systemctl restart bandwidth-monitor 2>/dev/null && echo -e "\033[0;32m服务端重启完成\033[0m" || echo -e "\033[0;31m服务端重启失败\033[0m"
        systemctl restart bandwidth-monitor-client 2>/dev/null && echo -e "\033[0;32m客户端重启完成\033[0m" || echo -e "\033[0;31m客户端重启失败\033[0m"
        ;;
      *) echo "无效选择";;
    esac
    ;;
  *)
    echo "用法: sudo restart bm"
    echo "重启 Bandwidth Monitor 服务"
    exit 1
    ;;
esac
EOF

# 设置可执行权限
chmod +x /usr/local/bin/bm
chmod +x /usr/local/bin/status
chmod +x /usr/local/bin/log
chmod +x /usr/local/bin/restart

log_success "简化命令安装完成！"
echo
log_info "可用命令："
echo "  sudo bm          - 打开控制面板"
echo "  status bm        - 查看服务状态" 
echo "  log bm           - 查看日志"
echo "  sudo restart bm  - 重启服务"
echo
echo -e "${YELLOW}注意: bm 和 restart 命令需要 sudo 权限${NC}"