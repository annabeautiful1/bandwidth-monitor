#!/bin/bash

# 带宽监控系统 - 客户端安装脚本
# 支持 Linux amd64/arm64 架构

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 项目信息
GITHUB_REPO="annabeautiful1/bandwidth-monitor"
SERVICE_NAME="bandwidth-monitor-client"
INSTALL_DIR="/opt/bandwidth-monitor-client"
CONFIG_FILE="$INSTALL_DIR/client.json"

echo -e "${BLUE}================================${NC}"
echo -e "${BLUE}  带宽监控系统 - 客户端安装程序   ${NC}"
echo -e "${BLUE}================================${NC}"
echo

# 检查是否为root用户
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}错误: 请使用 sudo 运行此脚本${NC}" 
   exit 1
fi

# 检测系统架构
ARCH=""
case $(uname -m) in
    x86_64)
        ARCH="amd64"
        ;;
    aarch64)
        ARCH="arm64"
        ;;
    *)
        echo -e "${RED}不支持的系统架构: $(uname -m)${NC}"
        exit 1
        ;;
esac

echo -e "${GREEN}检测到系统架构: $ARCH${NC}"

# 获取最新版本
echo -e "${YELLOW}正在获取最新版本信息...${NC}"

# 尝试多种方式获取版本信息
LATEST_VERSION=""

# 方法1: 直接使用GitHub API
if [ -z "$LATEST_VERSION" ]; then
    LATEST_VERSION=$(curl -s --max-time 10 "https://api.github.com/repos/$GITHUB_REPO/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/' 2>/dev/null)
fi

# 方法2: 如果有镜像源，尝试通过镜像访问API
if [ -z "$LATEST_VERSION" ] && [ -n "${RELEASE_MIRROR:-}" ]; then
    # 尝试镜像源的API（去掉镜像前缀，直接访问原始API）
    LATEST_VERSION=$(curl -s --max-time 10 "https://api.github.com/repos/$GITHUB_REPO/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/' 2>/dev/null)
fi

# 方法3: 使用预设的版本作为后备
if [ -z "$LATEST_VERSION" ]; then
    LATEST_VERSION="v0.3.1"  # 后备版本
    echo -e "${YELLOW}网络API访问失败，使用预设版本: $LATEST_VERSION${NC}"
else
    echo -e "${GREEN}最新版本: $LATEST_VERSION${NC}"
fi

# 下载URL（可通过 RELEASE_MIRROR 指定镜像前缀，例如 https://ghfast.top/）
BASE_GH="https://github.com"
if [ -n "${RELEASE_MIRROR:-}" ]; then
    BASE_GH="$RELEASE_MIRROR"
fi
DOWNLOAD_URL="$BASE_GH/$GITHUB_REPO/releases/download/$LATEST_VERSION/bandwidth-monitor-client-linux-$ARCH"

# 创建安装目录
echo -e "${YELLOW}创建安装目录...${NC}"
mkdir -p "$INSTALL_DIR"

# 下载二进制文件
echo -e "${YELLOW}正在下载客户端程序...${NC}"
if ! curl -L -o "$INSTALL_DIR/client" "$DOWNLOAD_URL"; then
    echo -e "${RED}下载失败，请检查网络连接或版本信息${NC}"
    exit 1
fi

# 设置执行权限
chmod +x "$INSTALL_DIR/client"

echo -e "${GREEN}客户端程序下载完成${NC}"

#############################################
# 配置收集（支持环境变量与 /dev/tty 交互）
#############################################
echo -e "${BLUE}开始配置收集...${NC}"

# 服务器地址（env: SERVER_URL）
if [ -n "${SERVER_URL:-}" ]; then
    server_url="$SERVER_URL"
else
    while true; do
        read -r -p "请输入服务器地址 (例: http://your-server.com:8080): " server_url </dev/tty || true
        if [[ "$server_url" =~ ^https?:// ]]; then
            break
        else
            echo -e "${RED}请输入完整的服务器地址，包含 http:// 或 https://${NC}"
        fi
    done
fi

# 访问密码（env: PASSWORD）
if [ -n "${PASSWORD:-}" ]; then
    password="$PASSWORD"
else
    while true; do
        read -r -s -p "请输入服务器访问密码: " password </dev/tty || true
        echo
        if [ -n "$password" ]; then
            break
        else
            echo -e "${RED}密码不能为空${NC}"
        fi
    done
fi

# 节点名称（env: HOSTNAME）
if [ -n "${HOSTNAME:-}" ]; then
    hostname="$HOSTNAME"
else
    default_hostname=$(hostname)
    read -r -p "请输入节点名称 (默认: $default_hostname): " hostname </dev/tty || true
    hostname=${hostname:-$default_hostname}
fi

# 上报间隔（env: REPORT_INTERVAL，默认 60，>=10）
if [ -n "${REPORT_INTERVAL:-}" ]; then
    report_interval="$REPORT_INTERVAL"
else
    while true; do
        read -r -p "请设置上报间隔 (秒，默认: 60): " report_interval </dev/tty || true
        report_interval=${report_interval:-60}
        if [[ "$report_interval" =~ ^[0-9]+$ ]] && [ "$report_interval" -ge 10 ]; then
            break
        else
            echo -e "${RED}请输入大于等于10的数字${NC}"
        fi
    done
fi

# 网卡选择（env: IFACE）
if [ -n "${IFACE:-}" ]; then
    iface="$IFACE"
else
    echo -e "${YELLOW}正在获取可用网卡...${NC}"
    mapfile -t IFACES < <(ls -1 /sys/class/net | grep -vE '^(lo|veth|docker|br-|virbr|vmnet|zt|tailscale|wg)')
    if [ ${#IFACES[@]} -eq 0 ]; then
        IFACES=(lo)
    fi
    echo "可选网卡:"
    for i in "${!IFACES[@]}"; do
        idx=$((i+1))
        echo "  $idx) ${IFACES[$i]}"
    done
    while true; do
        read -r -p "请选择用于监控的网卡编号 (默认1): " nic_idx </dev/tty || true
        nic_idx=${nic_idx:-1}
        if [[ "$nic_idx" =~ ^[0-9]+$ ]] && [ "$nic_idx" -ge 1 ] && [ "$nic_idx" -le ${#IFACES[@]} ]; then
            iface="${IFACES[$((nic_idx-1))]}"
            break
        else
            echo -e "${RED}无效选择，请重试${NC}"
        fi
    done
fi

# 阈值设置（客户端侧，支持动态窗口）
# 静态阈值（可选，0 表示不启用静态）
STATIC_BW="${STATIC_BW:-0}"
# 动态窗口默认：10:00-02:00 200Mbps，02:00-10:00 50Mbps
DAY_START="${DAY_START:-10:00}"
DAY_END="${DAY_END:-02:00}"
DAY_BW="${DAY_BW:-200}"
NIGHT_START="${NIGHT_START:-02:00}"
NIGHT_END="${NIGHT_END:-10:00}"
NIGHT_BW="${NIGHT_BW:-50}"

# 生成配置文件
echo -e "${YELLOW}正在生成配置文件...${NC}"
cat > "$CONFIG_FILE" << EOF
{
  "password": "$password",
  "server_url": "$server_url",
  "hostname": "$hostname",
  "report_interval_seconds": $report_interval,
  "interface_name": "${iface}",
  "threshold": {
    "static_bandwidth_mbps": ${STATIC_BW},
    "dynamic": [
      {"start": "${DAY_START}", "end": "${DAY_END}", "bandwidth_mbps": ${DAY_BW}},
      {"start": "${NIGHT_START}", "end": "${NIGHT_END}", "bandwidth_mbps": ${NIGHT_BW}}
    ]
  }
}
EOF

# 创建systemd服务
echo -e "${YELLOW}正在创建systemd服务...${NC}"
cat > "/etc/systemd/system/$SERVICE_NAME.service" << EOF
[Unit]
Description=Bandwidth Monitor Client
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=$INSTALL_DIR
ExecStart=$INSTALL_DIR/client -config=$CONFIG_FILE
Restart=on-failure
RestartSec=10s

[Install]
WantedBy=multi-user.target
EOF

# 重载systemd并启动服务
echo -e "${YELLOW}正在启动服务...${NC}"
systemctl daemon-reload
systemctl enable "$SERVICE_NAME"
systemctl start "$SERVICE_NAME"

# 检查服务状态
sleep 3
if systemctl is-active --quiet "$SERVICE_NAME"; then
    echo -e "${GREEN}✓ 服务启动成功${NC}"
    echo -e "监控网卡: ${iface:-自动选择}"
else
    echo -e "${RED}✗ 服务启动失败，请检查日志: journalctl -u $SERVICE_NAME${NC}"
    exit 1
fi

# 显示安装结果
echo
echo -e "${BLUE}================================${NC}"
echo -e "${GREEN}✓ 安装完成！${NC}"
echo -e "${BLUE}================================${NC}"
echo
echo -e "${YELLOW}客户端信息:${NC}"
echo "  - 安装目录: $INSTALL_DIR"
echo "  - 配置文件: $CONFIG_FILE"
echo "  - 服务器地址: $server_url"
echo "  - 节点名称: $hostname"
echo "  - 上报间隔: ${report_interval}秒"
echo "  - 监控网卡: ${iface:-自动选择}"
echo "  - 阈值: 静态=${STATIC_BW}Mbps; 动态=[${DAY_START}-${DAY_END}:${DAY_BW}Mbps, ${NIGHT_START}-${NIGHT_END}:${NIGHT_BW}Mbps]"
echo "  - 服务名称: $SERVICE_NAME"
echo

# 显示最近的日志
echo
echo -e "${YELLOW}最近的运行日志:${NC}"
journalctl -u "$SERVICE_NAME" --no-pager -n 5