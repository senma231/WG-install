#!/bin/bash
# -*- coding: utf-8 -*-

# WireGuard端口转发快速修复脚本
# 解决常见的端口转发连接问题
# 版本: 1.0.0

# 设置UTF-8编码环境
export LANG=C.UTF-8
export LC_ALL=C.UTF-8

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# 全局变量
WG_INTERFACE="wg0"
FORWARD_RULES_FILE="/etc/wireguard/port-forwards.conf"

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }

echo -e "${CYAN}WireGuard端口转发快速修复工具${NC}"
echo "=================================="
echo ""

# 检查root权限
if [[ $EUID -ne 0 ]]; then
    log_error "需要root权限运行"
    echo "请使用: sudo $0"
    exit 1
fi

# 1. 检查并修复WireGuard服务
log_info "检查WireGuard服务..."
if ! systemctl is-active --quiet wg-quick@$WG_INTERFACE; then
    log_warn "WireGuard服务未运行，正在启动..."
    systemctl start wg-quick@$WG_INTERFACE
    sleep 2
    if systemctl is-active --quiet wg-quick@$WG_INTERFACE; then
        log_success "WireGuard服务启动成功"
    else
        log_error "WireGuard服务启动失败"
        exit 1
    fi
else
    log_success "WireGuard服务运行正常"
fi

# 2. 检查IP转发
log_info "检查IP转发设置..."
if [[ $(cat /proc/sys/net/ipv4/ip_forward) != "1" ]]; then
    log_warn "IP转发未启用，正在启用..."
    echo 1 > /proc/sys/net/ipv4/ip_forward
    if ! grep -q "net.ipv4.ip_forward = 1" /etc/sysctl.conf; then
        echo "net.ipv4.ip_forward = 1" >> /etc/sysctl.conf
    fi
    log_success "IP转发已启用"
else
    log_success "IP转发已启用"
fi

# 3. 修复iptables规则
log_info "修复iptables规则..."
if [[ -f $FORWARD_RULES_FILE ]] && [[ -s $FORWARD_RULES_FILE ]]; then
    while IFS=':' read -r public_port client_name client_ip target_port service_name create_time; do
        log_info "修复规则: $public_port → $client_ip:$target_port"
        
        # 删除可能重复的规则
        iptables -t nat -D PREROUTING -p tcp --dport "$public_port" -j DNAT --to-destination "$client_ip:$target_port" 2>/dev/null || true
        iptables -D FORWARD -p tcp -d "$client_ip" --dport "$target_port" -j ACCEPT 2>/dev/null || true
        iptables -D FORWARD -p tcp -s "$client_ip" --sport "$target_port" -j ACCEPT 2>/dev/null || true
        iptables -D INPUT -p tcp --dport "$public_port" -j ACCEPT 2>/dev/null || true
        
        # 添加正确的规则
        iptables -t nat -I PREROUTING -p tcp --dport "$public_port" -j DNAT --to-destination "$client_ip:$target_port"
        iptables -I FORWARD -p tcp -d "$client_ip" --dport "$target_port" -j ACCEPT
        iptables -I FORWARD -p tcp -s "$client_ip" --sport "$target_port" -j ACCEPT
        iptables -I INPUT -p tcp --dport "$public_port" -j ACCEPT
        
        # 添加MASQUERADE规则确保返回流量正确
        iptables -t nat -I POSTROUTING -p tcp -d "$client_ip" --dport "$target_port" -j MASQUERADE
        
        echo "  ✓ 规则已修复"
    done < "$FORWARD_RULES_FILE"
    
    # 保存iptables规则
    if command -v iptables-save >/dev/null 2>&1; then
        iptables-save > /etc/iptables/rules.v4 2>/dev/null || true
        log_success "iptables规则已保存"
    fi
else
    log_warn "没有找到端口转发配置文件"
    echo "请先使用端口转发管理器添加规则"
fi

# 4. 检查并修复常见的网络问题
log_info "检查网络配置..."

# 确保WireGuard接口的转发规则
if ip link show $WG_INTERFACE >/dev/null 2>&1; then
    iptables -I FORWARD -i $WG_INTERFACE -j ACCEPT 2>/dev/null || true
    iptables -I FORWARD -o $WG_INTERFACE -j ACCEPT 2>/dev/null || true
    log_success "WireGuard接口转发规则已确保"
fi

# 5. 显示当前状态
echo ""
log_info "当前状态检查:"

# 显示WireGuard状态
if command -v wg >/dev/null 2>&1; then
    local peer_count=$(wg show $WG_INTERFACE peers 2>/dev/null | wc -l)
    echo "连接的客户端数: $peer_count"
    
    if [[ $peer_count -gt 0 ]]; then
        echo "客户端列表:"
        wg show $WG_INTERFACE | grep -E "(peer|allowed ips)" | while read line; do
            echo "  $line"
        done
    fi
fi

# 显示端口转发规则
echo ""
if [[ -f $FORWARD_RULES_FILE ]] && [[ -s $FORWARD_RULES_FILE ]]; then
    echo "端口转发规则:"
    while IFS=':' read -r public_port client_name client_ip target_port service_name create_time; do
        # 检查客户端是否在线
        if wg show $WG_INTERFACE | grep -q "$client_ip"; then
            echo -e "  ${GREEN}✓${NC} $service_name: $public_port → $client_name($client_ip):$target_port"
        else
            echo -e "  ${RED}✗${NC} $service_name: $public_port → $client_name($client_ip):$target_port (客户端离线)"
        fi
    done < "$FORWARD_RULES_FILE"
fi

# 6. 提供测试命令
echo ""
log_info "测试建议:"

# 获取公网IP
local public_ip=$(curl -s --connect-timeout 5 http://ipv4.icanhazip.com 2>/dev/null || curl -s --connect-timeout 5 http://members.3322.org/dyndns/getip 2>/dev/null)
if [[ -n $public_ip ]]; then
    echo "服务端公网IP: $public_ip"
    echo ""
    
    if [[ -f $FORWARD_RULES_FILE ]] && [[ -s $FORWARD_RULES_FILE ]]; then
        echo "测试连接命令:"
        while IFS=':' read -r public_port client_name client_ip target_port service_name create_time; do
            case $service_name in
                "RDP")
                    echo "  远程桌面: mstsc → $public_ip:$public_port"
                    ;;
                "SSH")
                    echo "  SSH连接: ssh user@$public_ip -p $public_port"
                    ;;
                "HTTP")
                    echo "  HTTP访问: http://$public_ip:$public_port"
                    ;;
                *)
                    echo "  $service_name: $public_ip:$public_port"
                    ;;
            esac
        done < "$FORWARD_RULES_FILE"
    fi
fi

# 7. Windows客户端检查提示
echo ""
log_info "Windows客户端检查清单:"
echo "1. 确认WireGuard客户端已连接"
echo "2. 检查Windows防火墙设置:"
echo "   netsh advfirewall firewall show rule name=all | findstr 端口号"
echo ""
echo "3. 启用RDP服务 (如果需要远程桌面):"
echo "   Set-ItemProperty -Path 'HKLM:\\System\\CurrentControlSet\\Control\\Terminal Server' -name 'fDenyTSConnections' -value 0"
echo "   Enable-NetFirewallRule -DisplayGroup 'Remote Desktop'"
echo ""
echo "4. 检查服务是否运行:"
echo "   Get-Service TermService  # RDP服务"
echo "   netstat -an | findstr :3389  # 检查端口监听"

# 8. VPS提供商防火墙提示
echo ""
log_warn "重要提醒:"
echo "如果仍无法连接，请检查VPS提供商的安全组/防火墙设置:"
echo "• 阿里云: 安全组规则"
echo "• 腾讯云: 安全组"
echo "• AWS: Security Groups"
echo "• Vultr/DigitalOcean: Firewall"
echo ""
echo "确保在云服务商控制台中开放了相应的端口！"

echo ""
log_success "快速修复完成！"
echo ""
echo "如果问题仍然存在，请运行详细诊断:"
echo "sudo ./port-forward-troubleshoot.sh"
