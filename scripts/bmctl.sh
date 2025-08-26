#!/bin/bash
# Bandwidth Monitor 统一控制脚本
# 支持交互和非交互两种模式
# 
# 交互模式：bash <(curl bmctl.sh)
# 非交互模式：bash <(curl bmctl.sh) <password> <server_url> <hostname> [interface] [interval]

set -e

# 全局变量
REPO="annabeautiful1/bandwidth-monitor"
RAW_BASE_GH="https://raw.githubusercontent.com/${REPO}/main"
RAW_PROXY=""  # 将由 auto_detect_mirror 函数设置

# 解析命令行参数
parse_arguments() {
    # 检查是否有参数
    if [ $# -eq 0 ]; then
        return 0  # 无参数，进入交互模式
    fi
    
    # 非交互模式参数验证
    if [ $# -lt 3 ]; then
        echo -e "\033[0;31m[错误] 非交互模式需要至少3个参数\033[0m" >&2
        echo "用法: bash <(curl bmctl.sh) <password> <server_url> <hostname> [interface] [interval]" >&2
        echo "示例: bash <(curl bmctl.sh) abc123 http://api.example.com:8080 CN-GZ-QZY-1G" >&2
        echo "完整: bash <(curl bmctl.sh) abc123 http://api.example.com:8080 CN-GZ-QZY-1G eth0 60" >&2
        exit 1
    fi
    
    # 提取参数
    CLIENT_PASSWORD="$1"
    CLIENT_SERVER_URL="$2" 
    CLIENT_HOSTNAME="$3"
    CLIENT_INTERFACE="${4:-}"     # 可选，默认为空（自动检测）
    CLIENT_INTERVAL="${5:-60}"    # 可选，默认60秒
    
    # 参数验证
    if [ -z "$CLIENT_PASSWORD" ] || [ -z "$CLIENT_SERVER_URL" ] || [ -z "$CLIENT_HOSTNAME" ]; then
        echo -e "\033[0;31m[错误] 密码、服务器地址和主机名不能为空\033[0m" >&2
        exit 1
    fi
    
    # URL格式验证
    if ! echo "$CLIENT_SERVER_URL" | grep -qE '^https?://[^/]+'; then
        echo -e "\033[0;31m[错误] 服务器地址格式不正确，需要包含 http:// 或 https://\033[0m" >&2
        echo "示例: http://api.example.com:8080" >&2
        exit 1
    fi
    
    # 间隔时间验证
    if ! echo "$CLIENT_INTERVAL" | grep -qE '^[0-9]+$' || [ "$CLIENT_INTERVAL" -lt 10 ] || [ "$CLIENT_INTERVAL" -gt 3600 ]; then
        echo -e "\033[0;31m[错误] 上报间隔必须是10-3600秒之间的数字\033[0m" >&2
        exit 1
    fi
    
    return 1  # 有参数，进入非交互模式
}

# 非交互模式：自动安装客户端
non_interactive_install() {
    echo -e "\033[0;34m[信息] 开始非交互模式客户端安装\033[0m"
    echo "参数信息:"
    echo "  服务器地址: $CLIENT_SERVER_URL"
    echo "  主机名: $CLIENT_HOSTNAME" 
    echo "  网卡: ${CLIENT_INTERFACE:-自动检测}"
    echo "  上报间隔: ${CLIENT_INTERVAL}秒"
    echo
    
    # 权限检查
    if [[ $EUID -ne 0 ]]; then
        echo -e "\033[0;31m[错误] 非交互模式需要root权限，请使用sudo运行\033[0m" >&2
        exit 1
    fi
    
    # 自动检测镜像源
    auto_detect_mirror
    
    # 执行客户端安装
    install_client_non_interactive
    
    echo -e "\033[0;32m[成功] 客户端安装完成！\033[0m"
    echo
    echo "管理命令:"
    echo "  查看状态: systemctl status bandwidth-monitor-client"
    echo "  查看日志: journalctl -u bandwidth-monitor-client -f"
    echo "  重启服务: systemctl restart bandwidth-monitor-client"
    echo "  停止服务: systemctl stop bandwidth-monitor-client"
    echo
    echo "快捷命令安装: sudo bash <(curl -sSL ${RAW_PROXY}${RAW_BASE_GH}/scripts/bmctl.sh)"
    
    exit 0
}

# 主程序入口
main() {
    # 解析参数并判断模式
    if parse_arguments "$@"; then
        # 交互模式
        interactive_mode
    else
        # 非交互模式
        non_interactive_install
    fi
}

# IP地理位置检测和镜像自动选择
auto_detect_mirror() {
  log_info "正在检测网络环境并选择最优镜像源..."
  
  # 检测是否为中国大陆IP
  local is_china=false
  
  # 方法1: 通过 ip-api.com 检测（免费且可靠）
  local country_code=""
  if command -v curl >/dev/null 2>&1; then
    country_code=$(curl -s --connect-timeout 5 --max-time 10 "http://ip-api.com/line?fields=countryCode" 2>/dev/null | head -n1)
    if [ "$country_code" = "CN" ]; then
      is_china=true
    fi
  fi
  
  # 方法2: 备用检测方式（通过访问速度测试）
  if [ -z "$country_code" ] || [ "$country_code" != "CN" ]; then
    log_info "使用备用检测方式..."
    # 测试访问 GitHub 和国内镜像的速度
    local github_time=999
    local mirror_time=999
    
    if command -v curl >/dev/null 2>&1; then
      # 测试 GitHub 访问速度 (超时5秒)
      github_time=$(curl -s -w "%{time_total}" --connect-timeout 5 --max-time 5 -o /dev/null "https://github.com" 2>/dev/null | cut -d'.' -f1)
      [ -z "$github_time" ] && github_time=999
      
      # 测试国内镜像访问速度 (超时5秒)  
      mirror_time=$(curl -s -w "%{time_total}" --connect-timeout 5 --max-time 5 -o /dev/null "https://ghfast.top" 2>/dev/null | cut -d'.' -f1)
      [ -z "$mirror_time" ] && mirror_time=999
      
      # 如果镜像访问明显更快，认为是国内网络环境
      if [ "$mirror_time" -lt "$github_time" ] && [ "$mirror_time" -lt 3 ]; then
        is_china=true
      fi
    fi
  fi
  
  # 设置镜像源
  if [ "$is_china" = true ]; then
    RAW_PROXY="https://ghfast.top/"
    export RELEASE_MIRROR="https://ghfast.top/"
    log_success "检测到中国大陆网络环境，使用国内镜像加速: ghfast.top"
  else
    RAW_PROXY=""
    export RELEASE_MIRROR=""
    log_success "检测到海外网络环境，使用 GitHub 源"
  fi
}

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

require_root() {
  if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}请使用 sudo 或 root 运行本脚本${NC}" >&2
    exit 1
  fi
}

raw_url() {
  local path="$1"
  echo "${RAW_PROXY}${RAW_BASE_GH}/${path}"
}

# 带重试机制的下载函数
download_with_fallback() {
  local url="$1"
  local max_retries=2
  local retry_count=0
  
  while [ $retry_count -lt $max_retries ]; do
    if curl -sSL "$url" 2>/dev/null; then
      return 0
    else
      retry_count=$((retry_count + 1))
      if [ $retry_count -lt $max_retries ]; then
        log_warning "下载失败，尝试切换镜像源..."
        # 切换镜像源
        if [ -n "$RAW_PROXY" ]; then
          # 当前使用镜像，切换到GitHub源
          RAW_PROXY=""
          export RELEASE_MIRROR=""
          log_info "切换到 GitHub 源重试..."
        else
          # 当前使用GitHub源，切换到镜像
          RAW_PROXY="https://ghfast.top/"
          export RELEASE_MIRROR="https://ghfast.top/"
          log_info "切换到国内镜像重试..."
        fi
        url="${RAW_PROXY}${RAW_BASE_GH}/${url##*/}"
        sleep 2
      fi
    fi
  done
  
  log_error "所有镜像源均下载失败"
  return 1
}

log_info() {
  echo -e "${BLUE}[信息]${NC} $1"
}

log_success() {
  echo -e "${GREEN}[成功]${NC} $1"
}

log_warning() {
  echo -e "${YELLOW}[警告]${NC} $1"
}

log_error() {
  echo -e "${RED}[错误]${NC} $1"
}

show_progress() {
  local msg="$1"
  echo -e "${CYAN}[进行中]${NC} $msg..."
}

ensure_jq() {
  if command -v jq >/dev/null 2>&1; then return; fi
  show_progress "安装 jq 工具"
  if command -v apt >/dev/null 2>&1; then
    apt update -y >/dev/null 2>&1 || true
    apt install -y jq >/dev/null 2>&1 || true
  elif command -v yum >/dev/null 2>&1; then
    yum install -y epel-release >/dev/null 2>&1 || true
    yum install -y jq >/dev/null 2>&1 || true
  fi
  if ! command -v jq >/dev/null 2>&1; then
    log_error "未安装 jq，请手动安装后重试 (apt install -y jq / yum install -y jq)"
    exit 1
  fi
  log_success "jq 工具安装完成"
}

# ---------- 服务端（主控） ----------
server_install_update() {
  show_progress "安装/更新服务端（主控）"
  
  # 检测系统架构
  ARCH=$(uname -m)
  case "$ARCH" in
      x86_64) ARCH="amd64" ;;
      aarch64) ARCH="arm64" ;;
      *) log_error "不支持的架构: $ARCH"; read -p "按 Enter 键继续..."; return 1 ;;
  esac
  
  # 获取最新版本
  log_info "正在获取最新版本信息..."
  LATEST_VERSION=$(curl -s --max-time 10 "https://api.github.com/repos/$REPO/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/' 2>/dev/null || echo "v0.3.1")
  log_success "最新版本: $LATEST_VERSION"
  
  # 设置下载URL
  BASE_GH="https://github.com"
  if [ -n "$RAW_PROXY" ]; then
      BASE_GH="$RAW_PROXY"
  fi
  DOWNLOAD_URL="$BASE_GH/$REPO/releases/download/$LATEST_VERSION/bandwidth-monitor-server-linux-$ARCH"
  
  # 创建安装目录
  INSTALL_DIR="/opt/bandwidth-monitor"
  mkdir -p "$INSTALL_DIR"
  
  # 下载二进制文件
  log_info "正在下载服务端程序..."
  if curl -L -o "$INSTALL_DIR/server" "$DOWNLOAD_URL"; then
      chmod +x "$INSTALL_DIR/server"
      log_success "服务端程序下载完成"
  else
      log_error "下载失败，请检查网络连接"
      read -p "按 Enter 键继续..."
      return 1
  fi
  
  # 创建或更新配置文件
  create_server_config_interactive
  
  # 创建systemd服务
  create_server_service
  
  # 重新加载并启动服务
  systemctl daemon-reload
  systemctl enable bandwidth-monitor
  if systemctl restart bandwidth-monitor 2>/dev/null; then
      log_success "服务端（主控）安装/更新完成"
      systemctl status bandwidth-monitor --no-pager -l
  else
      log_error "服务启动失败"
  fi
  
  read -p "按 Enter 键继续..."
}

server_restart() {
  show_progress "重启服务端（主控）"
  if systemctl restart bandwidth-monitor 2>/dev/null; then
    log_success "服务端（主控）重启完成"
    systemctl status bandwidth-monitor --no-pager -l
  else
    log_error "服务端（主控）重启失败"
  fi
  read -p "按 Enter 键继续..."
}

server_logs() {
  echo -e "${PURPLE}================= 服务端（主控）日志 =================${NC}"
  journalctl -u bandwidth-monitor -n 50 --no-pager -f
}

# ---------- 客户端（被控） ----------
client_install_update() {
  show_progress "安装/更新客户端（被控）"
  
  # 检测系统架构
  ARCH=$(uname -m)
  case "$ARCH" in
      x86_64) ARCH="amd64" ;;
      aarch64) ARCH="arm64" ;;
      *) log_error "不支持的架构: $ARCH"; read -p "按 Enter 键继续..."; return 1 ;;
  esac
  
  # 获取最新版本
  log_info "正在获取最新版本信息..."
  LATEST_VERSION=$(curl -s --max-time 10 "https://api.github.com/repos/$REPO/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/' 2>/dev/null || echo "v0.3.1")
  log_success "最新版本: $LATEST_VERSION"
  
  # 设置下载URL
  BASE_GH="https://github.com"
  if [ -n "$RAW_PROXY" ]; then
      BASE_GH="$RAW_PROXY"
  fi
  DOWNLOAD_URL="$BASE_GH/$REPO/releases/download/$LATEST_VERSION/bandwidth-monitor-client-linux-$ARCH"
  
  # 创建安装目录
  INSTALL_DIR="/opt/bandwidth-monitor-client"
  mkdir -p "$INSTALL_DIR"
  
  # 下载二进制文件
  log_info "正在下载客户端程序..."
  if curl -L -o "$INSTALL_DIR/client" "$DOWNLOAD_URL"; then
      chmod +x "$INSTALL_DIR/client"
      log_success "客户端程序下载完成"
  else
      log_error "下载失败，请检查网络连接"
      read -p "按 Enter 键继续..."
      return 1
  fi
  
  # 创建或更新配置文件
  create_client_config_interactive
  
  # 创建systemd服务
  create_client_service
  
  # 重新加载并启动服务
  systemctl daemon-reload
  systemctl enable bandwidth-monitor-client
  if systemctl restart bandwidth-monitor-client 2>/dev/null; then
      log_success "客户端（被控）安装/更新完成"
      systemctl status bandwidth-monitor-client --no-pager -l
  else
      log_error "服务启动失败"
  fi
  
  read -p "按 Enter 键继续..."
}

client_restart() {
  show_progress "重启客户端（被控）"
  if systemctl restart bandwidth-monitor-client 2>/dev/null; then
    log_success "客户端（被控）重启完成"
    systemctl status bandwidth-monitor-client --no-pager -l
  else
    log_error "客户端（被控）重启失败"
  fi
  read -p "按 Enter 键继续..."
}

client_logs() {
  echo -e "${PURPLE}================= 客户端（被控）日志 =================${NC}"
  journalctl -u bandwidth-monitor-client -n 50 --no-pager -f
}

CLIENT_CFG="/opt/bandwidth-monitor-client/client.json"

cfg_set() {
  ensure_jq
  local jq_expr="$1"
  show_progress "更新配置"
  tmp=$(mktemp)
  if jq "$jq_expr" "$CLIENT_CFG" >"$tmp" && mv -f "$tmp" "$CLIENT_CFG"; then
    log_success "配置更新完成"
    log_info "配置将在5秒内自动重载，无需重启服务"
  else
    log_error "配置更新失败"
  fi
}

set_high_peak_threshold() {
  echo -e "${CYAN}当前配置的高峰期（22:00-02:00）阈值：${NC}"
  jq -r '.threshold.dynamic[0].bandwidth_mbps' "$CLIENT_CFG" 2>/dev/null || echo "未找到配置"
  read -rp "请输入新的高峰期带宽阈值(Mbps): " val
  cfg_set ".threshold.dynamic[0].bandwidth_mbps = ($val|tonumber)"
}

set_low_valley_threshold() {
  echo -e "${CYAN}当前配置的低谷期（02:00-09:00）阈值：${NC}"
  jq -r '.threshold.dynamic[1].bandwidth_mbps' "$CLIENT_CFG" 2>/dev/null || echo "未找到配置"
  read -rp "请输入新的低谷期带宽阈值(Mbps): " val
  cfg_set ".threshold.dynamic[1].bandwidth_mbps = ($val|tonumber)"
}

set_normal_peak_threshold() {
  echo -e "${CYAN}当前配置的平峰期（09:00-22:00）阈值：${NC}"
  jq -r '.threshold.dynamic[2].bandwidth_mbps' "$CLIENT_CFG" 2>/dev/null || echo "未找到配置"
  read -rp "请输入新的平峰期带宽阈值(Mbps): " val
  cfg_set ".threshold.dynamic[2].bandwidth_mbps = ($val|tonumber)"
}

set_time_windows() {
  echo -e "${CYAN}当前时间段配置：${NC}"
  echo "高峰期: $(jq -r '.threshold.dynamic[0].start + "-" + .threshold.dynamic[0].end' "$CLIENT_CFG" 2>/dev/null || echo "未找到")"
  echo "低谷期: $(jq -r '.threshold.dynamic[1].start + "-" + .threshold.dynamic[1].end' "$CLIENT_CFG" 2>/dev/null || echo "未找到")"
  echo "平峰期: $(jq -r '.threshold.dynamic[2].start + "-" + .threshold.dynamic[2].end' "$CLIENT_CFG" 2>/dev/null || echo "未找到")"
  
  read -rp "请输入高峰期时间段(如 22:00-02:00): " peak
  read -rp "请输入低谷期时间段(如 02:00-09:00): " valley
  read -rp "请输入平峰期时间段(如 09:00-22:00): " normal
  
  IFS='-' read -r pstart pend <<<"$peak"
  IFS='-' read -r vstart vend <<<"$valley"
  IFS='-' read -r nstart nend <<<"$normal"
  
  ensure_jq
  tmp=$(mktemp)
  jq ".threshold.dynamic[0].start=\"$pstart\" | .threshold.dynamic[0].end=\"$pend\" | .threshold.dynamic[1].start=\"$vstart\" | .threshold.dynamic[1].end=\"$vend\" | .threshold.dynamic[2].start=\"$nstart\" | .threshold.dynamic[2].end=\"$nend\"" "$CLIENT_CFG" >"$tmp" && mv -f "$tmp" "$CLIENT_CFG"
  log_success "时间段配置已更新，将在5秒内自动重载"
}

set_client_name() {
  echo -e "${CYAN}当前客户端名称：${NC}$(jq -r '.hostname' "$CLIENT_CFG" 2>/dev/null || echo "未找到")"
  read -rp "请输入新的客户端名称(hostname): " name
  cfg_set ".hostname=\"$name\""
}

set_server_url() {
  echo -e "${CYAN}当前服务器地址：${NC}$(jq -r '.server_url' "$CLIENT_CFG" 2>/dev/null || echo "未找到")"
  read -rp "请输入新的对接地址(如 http://example.com:8080): " url
  cfg_set ".server_url=\"$url\""
}

set_report_interval() {
  echo -e "${CYAN}当前上报间隔：${NC}$(jq -r '.report_interval_seconds' "$CLIENT_CFG" 2>/dev/null || echo "未找到")秒"
  read -rp "请输入新的上报间隔(秒): " sec
  cfg_set ".report_interval_seconds = ($sec|tonumber)"
}

toggle_static_threshold() {
  echo -e "${CYAN}当前静态阈值：${NC}$(jq -r '.threshold.static_bandwidth_mbps' "$CLIENT_CFG" 2>/dev/null || echo "未找到")Mbps"
  read -rp "是否启用静态阈值? (y/n): " yn
  if [[ "$yn" =~ ^[Yy]$ ]]; then
    read -rp "请输入静态阈值(Mbps): " bw
    cfg_set ".threshold.static_bandwidth_mbps = ($bw|tonumber)"
  else
    cfg_set ".threshold.static_bandwidth_mbps = 0"
  fi
}

set_beijing_time() {
  show_progress "设置北京时间"
  timedatectl set-timezone Asia/Shanghai 2>/dev/null || true
  timedatectl set-ntp true 2>/dev/null || true
  log_success "已设置为北京时间(Asia/Shanghai)，并开启NTP"
  echo -e "${CYAN}当前时间：${NC}$(date)"
  
  # 检查是否有运行的服务
  services_to_restart=""
  if systemctl is-active --quiet bandwidth-monitor 2>/dev/null; then
    services_to_restart="${services_to_restart} bandwidth-monitor"
  fi
  if systemctl is-active --quiet bandwidth-monitor-client 2>/dev/null; then
    services_to_restart="${services_to_restart} bandwidth-monitor-client"
  fi
  
  if [ -n "$services_to_restart" ]; then
    echo
    log_info "时区已设置，运行中的服务会在5秒内自动检测新时区"
    log_info "如需立即生效，可选择重启服务：$services_to_restart"
    echo
    echo "选择操作："
    echo "1 等待自动生效 (推荐，5秒内生效)"
    echo "2 立即重启服务 (会产生上线/下线通知)"
    echo "0 跳过"
    read -rp "请选择 [0-2]: " restart_choice
    case "$restart_choice" in
      1)
        log_success "时区设置完成，服务会自动检测新时区并热重载"
        ;;
      2)
        for service in $services_to_restart; do
          show_progress "重启 $service 服务"
          if systemctl restart "$service" 2>/dev/null; then
            log_success "$service 重启完成"
          else
            log_error "$service 重启失败"
          fi
        done
        log_success "所有服务已重启，新时区设置已立即生效"
        ;;
      0|*)
        log_info "时区已设置，服务会在下次上报时自动应用新时区"
        ;;
    esac
  else
    log_info "未检测到运行中的服务，时区设置已生效"
  fi
  
  read -p "按 Enter 键继续..."
}

# 检查快捷命令是否已安装
check_shortcuts_installed() {
  [[ -f /usr/local/bin/bm ]] && [[ -f /usr/local/bin/status ]] && [[ -f /usr/local/bin/log ]] && [[ -f /usr/local/bin/restart ]]
}

# 静默安装快捷命令
install_shortcuts_silent() {
  install_shortcuts_core 2>/dev/null
  if check_shortcuts_installed; then
    log_success "快捷命令已自动安装 (bm, status bm, log bm, restart bm)"
  fi
}

# 核心安装逻辑
install_shortcuts_core() {
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

# 自动检测镜像源
auto_detect_mirror() {
  local is_china=false
  local country_code=""
  
  if command -v curl >/dev/null 2>&1; then
    country_code=$(curl -s --connect-timeout 3 --max-time 5 "http://ip-api.com/line?fields=countryCode" 2>/dev/null | head -n1)
    if [ "$country_code" = "CN" ]; then
      is_china=true
    fi
  fi
  
  if [ "$is_china" = true ]; then
    echo "https://ghfast.top/"
  else
    echo ""
  fi
}

RAW_PROXY=$(auto_detect_mirror)
bash <(curl -sSL "${RAW_PROXY}${RAW_BASE_GH}/scripts/bmctl.sh")
EOF

  # 创建 status 命令
  cat > /usr/local/bin/status << 'EOF'
#!/bin/bash
# 查看服务状态快捷命令

case "$1" in
  bm|bandwidth-monitor)
    echo "=== 服务端（主控）状态 ==="
    systemctl status bandwidth-monitor --no-pager -l 2>/dev/null || echo "服务端未安装"
    echo
    echo "=== 客户端（被控）状态 ==="
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
    # 自动检测安装的服务
    server_installed=false
    client_installed=false
    
    if systemctl list-unit-files bandwidth-monitor.service >/dev/null 2>&1 && systemctl is-enabled bandwidth-monitor >/dev/null 2>&1; then
      server_installed=true
    fi
    
    if systemctl list-unit-files bandwidth-monitor-client.service >/dev/null 2>&1 && systemctl is-enabled bandwidth-monitor-client >/dev/null 2>&1; then
      client_installed=true
    fi
    
    if [ "$server_installed" = true ] && [ "$client_installed" = true ]; then
      echo "检测到同时安装了服务端和客户端，显示两者日志:"
      echo
      echo "================= 服务端（主控）日志 ================="
      journalctl -u bandwidth-monitor -n 20 --no-pager
      echo
      echo "================= 客户端（被控）日志 ================="
      journalctl -u bandwidth-monitor-client -n 20 --no-pager
      echo
      echo "实时日志监控中... (按 Ctrl+C 退出)"
      echo "选择要监控的日志:"
      echo "1 服务端（主控）实时日志"
      echo "2 客户端（被控）实时日志" 
      echo "3 同时监控两者（分屏显示）"
      read -rp "选择 [1-3]: " choice
      case "$choice" in
        1) journalctl -u bandwidth-monitor -f;;
        2) journalctl -u bandwidth-monitor-client -f;;
        3) 
          echo "同时监控服务端和客户端日志..."
          journalctl -u bandwidth-monitor -u bandwidth-monitor-client -f
          ;;
        *) echo "无效选择，默认显示服务端日志"; journalctl -u bandwidth-monitor -f;;
      esac
    elif [ "$server_installed" = true ]; then
      echo "检测到服务端（主控），显示服务端日志:"
      journalctl -u bandwidth-monitor -n 50 --no-pager -f
    elif [ "$client_installed" = true ]; then
      echo "检测到客户端（被控），显示客户端日志:"
      journalctl -u bandwidth-monitor-client -n 50 --no-pager -f
    else
      echo "未检测到任何 Bandwidth Monitor 服务"
      echo "请先安装服务端或客户端"
    fi
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
    echo "1) 服务端（主控）"
    echo "2) 客户端（被控）"
    echo "3) 全部"
    read -rp "选择 [1-3]: " choice
    case "$choice" in
      1) 
        echo "重启服务端（主控）..."
        systemctl restart bandwidth-monitor 2>/dev/null && echo -e "\033[0;32m服务端重启完成\033[0m" || echo -e "\033[0;31m服务端重启失败\033[0m"
        systemctl status bandwidth-monitor --no-pager -l
        ;;
      2) 
        echo "重启客户端（被控）..."
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
}

config_menu() {
  while true; do
    clear
    echo -e "${PURPLE}================= 客户端（被控）配置修改 =================${NC}"
    echo "1 修改高峰期阈值 (22:00-02:00)"
    echo "2 修改低谷期阈值 (02:00-09:00)" 
    echo "3 修改平峰期阈值 (09:00-22:00)"
    echo "4 修改三个时间段"
    echo "5 修改客户端名称"
    echo "6 修改服务器地址"
    echo "7 修改上报间隔"
    echo "8 启用/关闭静态阈值"
    echo "0 返回主菜单"
    echo -e "${PURPLE}================================================${NC}"
    read -rp "请选择 [0-8]: " c
    case "$c" in
      1) set_high_peak_threshold; read -p "按 Enter 键继续...";;
      2) set_low_valley_threshold; read -p "按 Enter 键继续...";;
      3) set_normal_peak_threshold; read -p "按 Enter 键继续...";;
      4) set_time_windows; read -p "按 Enter 键继续...";;
      5) set_client_name; read -p "按 Enter 键继续...";;
      6) set_server_url; read -p "按 Enter 键继续...";;
      7) set_report_interval; read -p "按 Enter 键继续...";;
      8) toggle_static_threshold; read -p "按 Enter 键继续...";;
      0) break;;
      *) log_warning "无效选择"; sleep 1;;
    esac
  done
}

# 检查当前安装的版本信息
check_current_versions() {
  local server_status="❌ 未安装"
  local client_status="❌ 未安装"
  local server_config_status=""
  local client_config_status=""
  
  # 检查服务端
  if systemctl is-active --quiet bandwidth-monitor 2>/dev/null; then
    server_status="✅ 运行中"
    
    # 检查服务端配置是否有新字段
    if [ -f "/opt/bandwidth-monitor/config.json" ]; then
      if grep -q "cpu_percent" /opt/bandwidth-monitor/config.json && grep -q "memory_percent" /opt/bandwidth-monitor/config.json; then
        server_config_status=" | 配置: ✅ 已升级"
      else
        server_config_status=" | 配置: ⚠️ 需升级"
      fi
    fi
  elif [ -f "/opt/bandwidth-monitor/server" ]; then
    server_status="⏹️ 已安装未运行"
  fi
  
  # 检查客户端
  if systemctl is-active --quiet bandwidth-monitor-client 2>/dev/null; then
    client_status="✅ 运行中"
    
    # 检查客户端配置是否有完整的动态阈值
    if [ -f "/opt/bandwidth-monitor-client/client.json" ]; then
      local dynamic_count=$(grep -c '"start":' /opt/bandwidth-monitor-client/client.json 2>/dev/null || echo "0")
      if [ "$dynamic_count" -ge 3 ]; then
        client_config_status=" | 配置: ✅ 已升级"
      else
        client_config_status=" | 配置: ⚠️ 需升级"
      fi
    fi
  elif [ -f "/opt/bandwidth-monitor-client/client" ]; then
    client_status="⏹️ 已安装未运行"
  fi
  
  # 检查并自动安装/更新快捷命令
  local shortcut_status=""
  if ! check_shortcuts_installed; then
    shortcut_status=" | 快捷命令: 🔄 自动安装中..."
    install_shortcuts_silent
    if check_shortcuts_installed; then
      shortcut_status=" | 快捷命令: ✅ 已安装"
    else
      shortcut_status=" | 快捷命令: ❌ 安装失败"
    fi
  else
    shortcut_status=" | 快捷命令: ✅ 已安装"
  fi
  
  echo -e "${CYAN}当前版本状态:${NC}"
  echo "  服务端: $server_status$server_config_status"
  echo "  客户端: $client_status$client_config_status"
  echo "  系统工具: v0.3.0$shortcut_status"
  echo "  最新版本: v0.3.0 (时区热更新+CPU/内存告警+配置自动升级)"
}

interactive_mode() {
  require_root
  
  # 自动检测并设置镜像源
  auto_detect_mirror
  
  while true; do
    clear
    echo -e "${PURPLE}╔══════════════════════════════════════════╗${NC}"
    echo -e "${PURPLE}║${NC}          ${CYAN}Bandwidth Monitor${NC} 控制面板         ${PURPLE}║${NC}"
    echo -e "${PURPLE}╚══════════════════════════════════════════╝${NC}"
    echo
    echo -e "${CYAN}镜像源:${NC} ${RAW_PROXY:-GitHub 源}"
    echo
    echo "1 安装/更新服务端（主控）"
    echo "2 重启服务端（主控）" 
    echo "3 安装/更新客户端（被控）"
    echo "4 重启客户端（被控）"
    echo "5 客户端（被控）配置修改"
    echo "6 一键设置北京时间"
    echo
    echo "7 查看服务端（主控）日志"
    echo "8 查看客户端（被控）日志"
    echo
    echo -e "${RED}0${NC} 退出"
    echo -e "${PURPLE}================================================${NC}"
    
    # 显示版本信息
    check_current_versions
    echo -e "${PURPLE}================================================${NC}"
    
    read -rp "请选择 [0-8]: " a
    case "$a" in
      1) server_install_update;;
      2) server_restart;;
      3) client_install_update;;
      4) client_restart;;
      5) config_menu;;
      6) set_beijing_time;;
      7) server_logs;;
      8) client_logs;;
      0) echo -e "${GREEN}感谢使用！${NC}"; exit 0;;
      *) log_warning "无效选择"; sleep 1;;
    esac
  done
}

# 非交互模式客户端安装函数
install_client_non_interactive() {
    echo -e "\033[0;33m[信息] 正在安装客户端...\033[0m"
    
    # 检测系统架构
    ARCH=$(uname -m)
    case "$ARCH" in
        x86_64) ARCH="amd64" ;;
        aarch64) ARCH="arm64" ;;
        *) echo -e "\033[0;31m[错误] 不支持的架构: $ARCH\033[0m" >&2; exit 1 ;;
    esac
    
    # 获取最新版本
    echo -e "\033[0;33m[信息] 正在获取最新版本信息...\033[0m"
    LATEST_VERSION=$(curl -s --max-time 10 "https://api.github.com/repos/$REPO/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/' 2>/dev/null || echo "v0.3.1")
    echo -e "\033[0;32m[成功] 最新版本: $LATEST_VERSION\033[0m"
    
    # 设置下载URL
    BASE_GH="https://github.com"
    if [ -n "$RAW_PROXY" ]; then
        BASE_GH="$RAW_PROXY"
    fi
    DOWNLOAD_URL="$BASE_GH/$REPO/releases/download/$LATEST_VERSION/bandwidth-monitor-client-linux-$ARCH"
    
    # 创建安装目录
    INSTALL_DIR="/opt/bandwidth-monitor-client"
    mkdir -p "$INSTALL_DIR"
    
    # 下载二进制文件
    echo -e "\033[0;33m[信息] 正在下载客户端程序...\033[0m"
    if ! curl -L -o "$INSTALL_DIR/client" "$DOWNLOAD_URL"; then
        echo -e "\033[0;31m[错误] 下载失败，请检查网络连接\033[0m" >&2
        exit 1
    fi
    chmod +x "$INSTALL_DIR/client"
    
    # 创建配置文件
    create_client_config_non_interactive
    
    # 创建systemd服务
    create_client_service
    
    # 启动服务
    systemctl daemon-reload
    systemctl enable bandwidth-monitor-client
    systemctl start bandwidth-monitor-client
    
    echo -e "\033[0;32m[成功] 客户端安装并启动完成\033[0m"
}

# 创建客户端配置文件（非交互模式）
create_client_config_non_interactive() {
    local config_file="$INSTALL_DIR/client.json"
    
    echo -e "\033[0;33m[信息] 正在生成配置文件...\033[0m"
    
    cat > "$config_file" << EOF
{
  "password": "$CLIENT_PASSWORD",
  "server_url": "$CLIENT_SERVER_URL",
  "hostname": "$CLIENT_HOSTNAME",
  "report_interval_seconds": $CLIENT_INTERVAL,
  "interface_name": "$CLIENT_INTERFACE",
  "threshold": {
    "static_bandwidth_mbps": 0,
    "dynamic": [
      {"start": "22:00", "end": "02:00", "bandwidth_mbps": 200},
      {"start": "02:00", "end": "09:00", "bandwidth_mbps": 50},
      {"start": "09:00", "end": "22:00", "bandwidth_mbps": 100}
    ]
  }
}
EOF
    
    echo -e "\033[0;32m[成功] 配置文件已生成: $config_file\033[0m"
}

# 创建客户端systemd服务
create_client_service() {
    echo -e "\033[0;33m[信息] 正在创建systemd服务...\033[0m"
    
    cat > /etc/systemd/system/bandwidth-monitor-client.service << EOF
[Unit]
Description=Bandwidth Monitor Client
After=network.target
Wants=network.target

[Service]
Type=simple
User=root
Group=root
ExecStart=$INSTALL_DIR/client -config $INSTALL_DIR/client.json
Restart=always
RestartSec=5
StandardOutput=journal
StandardError=journal
SyslogIdentifier=client

[Install]
WantedBy=multi-user.target
EOF
    
    echo -e "\033[0;32m[成功] systemd服务已创建\033[0m"
}

# 创建服务端配置文件（交互模式）
create_server_config_interactive() {
    local config_file="$INSTALL_DIR/config.json"
    
    if [ -f "$config_file" ]; then
        log_info "检测到现有配置文件，保留现有设置"
        return 0
    fi
    
    log_info "创建服务端配置文件..."
    echo "需要配置以下信息："
    
    # 获取配置信息
    read -rp "请输入访问密码: " password
    read -rp "请输入监听端口 (默认8080): " port
    port=${port:-8080}
    read -rp "请输入Telegram Bot Token (可选): " bot_token
    if [ -n "$bot_token" ]; then
        read -rp "请输入Telegram Chat ID: " chat_id
    fi
    
    cat > "$config_file" << EOF
{
  "password": "$password",
  "listen": ":$port",
  "domain": "localhost",
  "telegram": {
    "bot_token": "${bot_token:-}",
    "chat_id": ${chat_id:-0}
  },
  "thresholds": {
    "bandwidth_mbps": 100,
    "offline_seconds": 300,
    "cpu_percent": 95,
    "memory_percent": 95
  }
}
EOF
    
    log_success "配置文件已生成: $config_file"
}

# 创建客户端配置文件（交互模式）
create_client_config_interactive() {
    local config_file="$INSTALL_DIR/client.json"
    
    if [ -f "$config_file" ]; then
        log_info "检测到现有配置文件，保留现有设置"
        return 0
    fi
    
    log_info "创建客户端配置文件..."
    echo "需要配置以下信息："
    
    # 获取配置信息
    read -rp "请输入访问密码: " password
    read -rp "请输入服务器地址 (如 http://example.com:8080): " server_url
    read -rp "请输入节点名称: " hostname
    read -rp "请输入网卡名称 (留空自动检测): " interface_name
    read -rp "请输入上报间隔秒数 (默认60): " interval
    interval=${interval:-60}
    
    cat > "$config_file" << EOF
{
  "password": "$password",
  "server_url": "$server_url",
  "hostname": "$hostname",
  "report_interval_seconds": $interval,
  "interface_name": "$interface_name",
  "threshold": {
    "static_bandwidth_mbps": 0,
    "dynamic": [
      {"start": "22:00", "end": "02:00", "bandwidth_mbps": 200},
      {"start": "02:00", "end": "09:00", "bandwidth_mbps": 50},
      {"start": "09:00", "end": "22:00", "bandwidth_mbps": 100}
    ]
  }
}
EOF
    
    log_success "配置文件已生成: $config_file"
}

# 创建服务端systemd服务
create_server_service() {
    log_info "正在创建服务端systemd服务..."
    
    cat > /etc/systemd/system/bandwidth-monitor.service << EOF
[Unit]
Description=Bandwidth Monitor Server
After=network.target
Wants=network.target

[Service]
Type=simple
User=root
Group=root
ExecStart=$INSTALL_DIR/server -config $INSTALL_DIR/config.json
Restart=always
RestartSec=5
StandardOutput=journal
StandardError=journal
SyslogIdentifier=server

[Install]
WantedBy=multi-user.target
EOF
    
    log_success "systemd服务已创建"
}

# 启动主程序
main "$@"

