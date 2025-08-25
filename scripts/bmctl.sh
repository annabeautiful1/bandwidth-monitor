#!/bin/bash
# Bandwidth Monitor 控制脚本（安装/更新/日志/配置）
# 支持 GitHub 源与中国大陆加速镜像（ghproxy）

set -e

REPO="annabeautiful1/bandwidth-monitor"
RAW_BASE_GH="https://raw.githubusercontent.com/${REPO}/main"
RAW_PROXY=""  # 置为 https://ghproxy.com/ 可走国内镜像

require_root() {
  if [[ $EUID -ne 0 ]]; then
    echo "请使用 sudo 或 root 运行本脚本" >&2
    exit 1
  fi
}

raw_url() {
  local path="$1"
  echo "${RAW_PROXY}${RAW_BASE_GH}/${path}"
}

ensure_jq() {
  if command -v jq >/dev/null 2>&1; then return; fi
  if command -v apt >/dev/null 2>&1; then
    apt update -y >/dev/null 2>&1 || true
    apt install -y jq >/dev/null 2>&1 || true
  elif command -v yum >/dev/null 2>&1; then
    yum install -y epel-release >/dev/null 2>&1 || true
    yum install -y jq >/dev/null 2>&1 || true
  fi
  if ! command -v jq >/dev/null 2>&1; then
    echo "未安装 jq，请手动安装后重试 (apt install -y jq / yum install -y jq)" >&2
    exit 1
  fi
}

# ---------- 服务端 ----------
server_install() {
  bash <(curl -sSL "$(raw_url scripts/install-server.sh)")
}

server_update() {
  RELEASE_MIRROR="${RELEASE_MIRROR:-${RAW_PROXY}}" \
  bash <(curl -sSL "$(raw_url scripts/update-server.sh)")
}

server_logs() {
  journalctl -u bandwidth-monitor -n 200 --no-pager
}

# ---------- 客户端 ----------
client_install() {
  bash <(curl -sSL "$(raw_url scripts/install-client.sh)")
}

client_update() {
  RELEASE_MIRROR="${RELEASE_MIRROR:-${RAW_PROXY}}" \
  bash <(curl -sSL "$(raw_url scripts/update-client.sh)")
}

client_logs() {
  journalctl -u bandwidth-monitor-client -n 200 --no-pager
}

CLIENT_CFG="/opt/bandwidth-monitor-client/client.json"

cfg_set() {
  ensure_jq
  local jq_expr="$1"
  tmp=$(mktemp)
  jq "$jq_expr" "$CLIENT_CFG" >"$tmp" && mv -f "$tmp" "$CLIENT_CFG"
  systemctl restart bandwidth-monitor-client || true
  echo "✓ 已更新并重启客户端"
}

set_peak_threshold() {
  read -rp "请输入高峰期带宽阈值(Mbps): " val
  cfg_set ".threshold.dynamic[0].bandwidth_mbps = ($val|tonumber)"
}

set_valley_threshold() {
  read -rp "请输入低谷期带宽阈值(Mbps): " val
  cfg_set ".threshold.dynamic[1].bandwidth_mbps = ($val|tonumber)"
}

set_time_window() {
  read -rp "请输入高峰期时间段(如 10:00-02:00): " peak
  read -rp "请输入低谷期时间段(如 02:00-10:00): " valley
  IFS='-' read -r pstart pend <<<"$peak"
  IFS='-' read -r vstart vend <<<"$valley"
  ensure_jq
  tmp=$(mktemp)
  jq ".threshold.dynamic[0].start=\"$pstart\" | .threshold.dynamic[0].end=\"$pend\" | .threshold.dynamic[1].start=\"$vstart\" | .threshold.dynamic[1].end=\"$vend\"" "$CLIENT_CFG" >"$tmp" && mv -f "$tmp" "$CLIENT_CFG"
  systemctl restart bandwidth-monitor-client || true
  echo "✓ 已更新峰谷时间并重启客户端"
}

set_client_name() {
  read -rp "请输入新的客户端名称(hostname): " name
  cfg_set ".hostname=\"$name\""
}

set_server_url() {
  read -rp "请输入新的对接地址(如 http://example.com:8080): " url
  cfg_set ".server_url=\"$url\""
}

set_report_interval() {
  read -rp "请输入新的上报间隔(秒): " sec
  cfg_set ".report_interval_seconds = ($sec|tonumber)"
}

toggle_static_threshold() {
  read -rp "是否启用静态阈值? (y/n): " yn
  if [[ "$yn" =~ ^[Yy]$ ]]; then
    read -rp "请输入静态阈值(Mbps): " bw
    cfg_set ".threshold.static_bandwidth_mbps = ($bw|tonumber)"
  else
    cfg_set ".threshold.static_bandwidth_mbps = 0"
  fi
}

set_beijing_time() {
  timedatectl set-timezone Asia/Shanghai || true
  timedatectl set-ntp true || true
  echo "✓ 已设置为北京时间(Asia/Shanghai)，并开启NTP"
}

choose_mirror() {
  echo "当前镜像: ${RAW_PROXY:-GitHub 源}"
  echo "1) 使用 GitHub 源"
  echo "2) 使用中国大陆镜像(ghproxy)"
  read -rp "选择: " op
  case "$op" in
    1) RAW_PROXY=""; export RELEASE_MIRROR="";;
    2) RAW_PROXY="https://ghproxy.com/"; export RELEASE_MIRROR="https://ghproxy.com/";;
  esac
}

menu_server() {
  while true; do
    cat <<EOF
================= 服务端功能 =================
1) 安装服务端
2) 更新服务端
3) 查看服务端日志
0) 返回上级
=============================================
EOF
    read -rp "选择: " c
    case "$c" in
      1) server_install;;
      2) server_update;;
      3) server_logs;;
      0) break;;
    esac
  done
}

menu_client() {
  while true; do
    cat <<EOF
================= 客户端功能 =================
1) 安装客户端
2) 更新客户端
3) 查看客户端日志
---------------------------------------------
4) 修改高峰期阈值
5) 修改低谷期阈值
6) 修改峰谷时间段
7) 修改客户端名称
8) 修改对接地址
9) 修改上报时间
10) 启用/关闭静态阈值
0) 返回上级
=============================================
EOF
    read -rp "选择: " c
    case "$c" in
      1) client_install;;
      2) client_update;;
      3) client_logs;;
      4) set_peak_threshold;;
      5) set_valley_threshold;;
      6) set_time_window;;
      7) set_client_name;;
      8) set_server_url;;
      9) set_report_interval;;
      10) toggle_static_threshold;;
      0) break;;
    esac
  done
}

main_menu() {
  require_root
  while true; do
    cat <<EOF
=============== Bandwidth Monitor ===============
镜像: ${RAW_PROXY:-GitHub 源}    (m) 切换镜像

1) 服务端功能
2) 客户端功能
3) 一键将系统时间设置为北京时间
q) 退出
================================================
EOF
    read -rp "选择: " a
    case "$a" in
      m|M) choose_mirror;;
      1) menu_server;;
      2) menu_client;;
      3) set_beijing_time;;
      q|Q) exit 0;;
    esac
  done
}

main_menu


