#!/bin/bash
# -*- coding: utf-8 -*-

# WireGuard端口转发故障排查脚本
# 专门用于诊断端口转发连接问题
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
WHITE='\033[1;37m'
NC='\033[0m'

# 全局变量
WG_CONFIG_DIR="/etc/wireguard"
WG_INTERFACE="wg0"
FORWARD_RULES_FILE="/etc/wireguard/port-forwards.conf"

# 日志函数
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_check() {
    echo -e "${BLUE}[CHECK]${NC} $1"
}

# 显示横幅
show_banner() {
    clear
    echo -e "${CYAN}"
    cat << "EOF"
╔══════════════════════════════════════════════════════════════╗
║            WireGuard端口转发故障排查工具                      ║
║                                                              ║
║  🔍 诊断项目:                                                 ║
║  • 服务端网络配置检查                                          ║
║  • iptables规则验证                                           ║
║  • 客户端连接状态                                              ║
║  • 端口监听状态                                                ║
║  • 网络连通性测试                                              ║
║                                                              ║
╚══════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
    echo ""
}

# 检查root权限
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "此脚本需要root权限运行"
        echo "请使用: sudo $0"
        exit 1
    fi
}

# 1. 检查WireGuard服务状态
check_wireguard_service() {
    log_check "检查WireGuard服务状态..."
    
    if systemctl is-active --quiet wg-quick@$WG_INTERFACE; then
        log_success "WireGuard服务运行正常"
        
        # 显示接口信息
        if ip link show $WG_INTERFACE >/dev/null 2>&1; then
            local wg_ip=$(ip addr show $WG_INTERFACE | grep "inet " | awk '{print $2}')
            echo "  接口IP: $wg_ip"
        fi
        
        # 显示连接的客户端
        local peer_count=$(wg show $WG_INTERFACE peers 2>/dev/null | wc -l)
        echo "  连接的客户端数: $peer_count"
        
    else
        log_error "WireGuard服务未运行"
        echo "  请启动服务: sudo systemctl start wg-quick@$WG_INTERFACE"
        return 1
    fi
    echo ""
}

# 2. 检查服务端公网IP
check_server_public_ip() {
    log_check "检查服务端公网IP..."
    
    local public_ip=$(curl -s --connect-timeout 5 http://ipv4.icanhazip.com 2>/dev/null || curl -s --connect-timeout 5 http://members.3322.org/dyndns/getip 2>/dev/null)
    
    if [[ -n $public_ip ]]; then
        log_success "服务端公网IP: $public_ip"
        
        # 检查IP是否可达
        if ping -c 1 -W 3 $public_ip >/dev/null 2>&1; then
            echo "  IP连通性: 正常"
        else
            log_warn "  IP连通性: 异常（可能是防火墙阻止了ICMP）"
        fi
    else
        log_error "无法获取服务端公网IP"
        echo "  请检查网络连接"
        return 1
    fi
    echo ""
}

# 3. 检查端口转发规则
check_port_forward_rules() {
    log_check "检查端口转发规则..."
    
    if [[ ! -f $FORWARD_RULES_FILE ]] || [[ ! -s $FORWARD_RULES_FILE ]]; then
        log_error "没有找到端口转发规则"
        echo "  请先使用端口转发管理器添加规则"
        return 1
    fi
    
    echo "当前端口转发规则："
    while IFS=':' read -r public_port client_name client_ip target_port service_name create_time; do
        echo "  $service_name: $public_port → $client_name($client_ip):$target_port"
    done < "$FORWARD_RULES_FILE"
    echo ""
}

# 4. 检查iptables规则
check_iptables_rules() {
    log_check "检查iptables规则..."
    
    if [[ ! -f $FORWARD_RULES_FILE ]]; then
        log_warn "没有端口转发配置文件"
        return 1
    fi
    
    local rules_ok=true
    
    while IFS=':' read -r public_port client_name client_ip target_port service_name create_time; do
        echo "检查规则: $public_port → $client_ip:$target_port"
        
        # 检查DNAT规则
        if iptables -t nat -C PREROUTING -p tcp --dport "$public_port" -j DNAT --to-destination "$client_ip:$target_port" 2>/dev/null; then
            echo "  ✓ DNAT规则存在"
        else
            echo "  ✗ DNAT规则缺失"
            rules_ok=false
        fi
        
        # 检查FORWARD规则
        if iptables -C FORWARD -p tcp -d "$client_ip" --dport "$target_port" -j ACCEPT 2>/dev/null; then
            echo "  ✓ FORWARD规则存在"
        else
            echo "  ✗ FORWARD规则缺失"
            rules_ok=false
        fi
        
        # 检查INPUT规则
        if iptables -C INPUT -p tcp --dport "$public_port" -j ACCEPT 2>/dev/null; then
            echo "  ✓ INPUT规则存在"
        else
            echo "  ✗ INPUT规则缺失"
            rules_ok=false
        fi
        
    done < "$FORWARD_RULES_FILE"
    
    if [[ $rules_ok == true ]]; then
        log_success "所有iptables规则正常"
    else
        log_error "部分iptables规则缺失"
        echo "  建议重新添加端口转发规则"
    fi
    echo ""
}

# 5. 检查客户端连接状态
check_client_status() {
    log_check "检查客户端连接状态..."
    
    if [[ ! -f $FORWARD_RULES_FILE ]]; then
        log_warn "没有端口转发配置文件"
        return 1
    fi
    
    while IFS=':' read -r public_port client_name client_ip target_port service_name create_time; do
        echo "检查客户端: $client_name ($client_ip)"
        
        # 检查客户端是否在WireGuard中
        if wg show $WG_INTERFACE | grep -q "$client_ip"; then
            log_success "  客户端已连接到WireGuard"
            
            # 显示连接信息
            local peer_info=$(wg show $WG_INTERFACE | grep -A 5 -B 1 "$client_ip")
            if [[ -n $peer_info ]]; then
                local last_handshake=$(echo "$peer_info" | grep "latest handshake" | cut -d':' -f2- | xargs)
                if [[ -n $last_handshake ]]; then
                    echo "  最后握手: $last_handshake"
                fi
            fi
            
        else
            log_error "  客户端未连接到WireGuard"
            echo "  请检查客户端WireGuard配置和连接状态"
        fi
        
        # 测试到客户端的连通性
        if ping -c 1 -W 3 "$client_ip" >/dev/null 2>&1; then
            log_success "  到客户端的网络连通性正常"
        else
            log_error "  无法ping通客户端"
            echo "  可能原因: 客户端防火墙阻止ICMP或客户端离线"
        fi
        
    done < "$FORWARD_RULES_FILE"
    echo ""
}

# 6. 检查端口监听状态
check_port_listening() {
    log_check "检查端口监听状态..."
    
    if [[ ! -f $FORWARD_RULES_FILE ]]; then
        log_warn "没有端口转发配置文件"
        return 1
    fi
    
    while IFS=':' read -r public_port client_name client_ip target_port service_name create_time; do
        echo "检查端口: $public_port (转发到 $client_ip:$target_port)"
        
        # 检查服务端公网端口是否监听
        if ss -tulpn | grep ":$public_port " >/dev/null 2>&1; then
            log_warn "  服务端端口 $public_port 被其他服务占用"
            ss -tulpn | grep ":$public_port "
        else
            echo "  服务端端口 $public_port 未被占用（正常，由iptables转发）"
        fi
        
        # 尝试从服务端连接到客户端目标端口
        if timeout 3 bash -c "echo >/dev/tcp/$client_ip/$target_port" 2>/dev/null; then
            log_success "  客户端端口 $target_port 可连接"
        else
            log_error "  客户端端口 $target_port 无法连接"
            echo "  可能原因:"
            echo "    - 客户端服务未启动"
            echo "    - 客户端防火墙阻止连接"
            echo "    - 服务监听在127.0.0.1而非0.0.0.0"
        fi
        
    done < "$FORWARD_RULES_FILE"
    echo ""
}

# 7. 测试外部连接
test_external_connection() {
    log_check "测试外部连接..."
    
    if [[ ! -f $FORWARD_RULES_FILE ]]; then
        log_warn "没有端口转发配置文件"
        return 1
    fi
    
    local public_ip=$(curl -s --connect-timeout 5 http://ipv4.icanhazip.com 2>/dev/null)
    if [[ -z $public_ip ]]; then
        log_error "无法获取公网IP，跳过外部连接测试"
        return 1
    fi
    
    while IFS=':' read -r public_port client_name client_ip target_port service_name create_time; do
        echo "测试外部连接: $public_ip:$public_port"
        
        # 使用telnet测试连接
        if command -v telnet >/dev/null 2>&1; then
            if timeout 5 telnet $public_ip $public_port </dev/null 2>/dev/null | grep -q "Connected"; then
                log_success "  外部连接测试成功"
            else
                log_error "  外部连接测试失败"
            fi
        else
            # 使用nc测试连接
            if command -v nc >/dev/null 2>&1; then
                if timeout 3 nc -z $public_ip $public_port 2>/dev/null; then
                    log_success "  外部连接测试成功"
                else
                    log_error "  外部连接测试失败"
                fi
            else
                log_warn "  无法进行外部连接测试（缺少telnet或nc工具）"
            fi
        fi
        
    done < "$FORWARD_RULES_FILE"
    echo ""
}

# 8. 检查系统防火墙
check_system_firewall() {
    log_check "检查系统防火墙..."
    
    # 检查UFW
    if command -v ufw >/dev/null 2>&1; then
        local ufw_status=$(ufw status | head -1)
        echo "UFW状态: $ufw_status"
        
        if echo "$ufw_status" | grep -q "active"; then
            echo "UFW规则:"
            ufw status numbered | grep -E "(ALLOW|DENY)"
        fi
    fi
    
    # 检查firewalld
    if command -v firewall-cmd >/dev/null 2>&1 && systemctl is-active --quiet firewalld; then
        echo "firewalld状态: 活跃"
        echo "开放端口:"
        firewall-cmd --list-ports
    fi
    
    # 检查iptables基本规则
    echo ""
    echo "iptables INPUT链规则数: $(iptables -L INPUT --line-numbers | wc -l)"
    echo "iptables FORWARD链规则数: $(iptables -L FORWARD --line-numbers | wc -l)"
    echo "iptables NAT PREROUTING规则数: $(iptables -t nat -L PREROUTING --line-numbers | wc -l)"
    echo ""
}

# 9. 生成修复建议
generate_fix_suggestions() {
    log_info "生成修复建议..."
    echo ""
    echo -e "${CYAN}=== 常见问题修复建议 ===${NC}"
    echo ""
    
    echo "1. 🔧 如果iptables规则缺失:"
    echo "   sudo ./port-forward-manager.sh"
    echo "   重新添加端口转发规则"
    echo ""
    
    echo "2. 🔌 如果客户端未连接:"
    echo "   检查Windows客户端WireGuard是否连接"
    echo "   验证客户端配置文件是否正确"
    echo "   重启客户端WireGuard服务"
    echo ""
    
    echo "3. 🛡️ 如果客户端端口无法连接:"
    echo "   Windows防火墙设置:"
    echo "   netsh advfirewall firewall add rule name=\"Allow Port\" dir=in action=allow protocol=TCP localport=目标端口"
    echo ""
    echo "   启用RDP服务:"
    echo "   Set-ItemProperty -Path 'HKLM:\\System\\CurrentControlSet\\Control\\Terminal Server' -name 'fDenyTSConnections' -value 0"
    echo "   Enable-NetFirewallRule -DisplayGroup 'Remote Desktop'"
    echo ""
    
    echo "4. 🌐 如果外部连接失败:"
    echo "   检查VPS提供商的安全组/防火墙设置"
    echo "   确认公网端口在云服务商控制台中已开放"
    echo "   测试从不同网络环境连接"
    echo ""
    
    echo "5. 🔄 重启相关服务:"
    echo "   sudo systemctl restart wg-quick@wg0"
    echo "   sudo iptables-restore < /etc/iptables/rules.v4"
    echo ""
}

# 10. 交互式修复
interactive_fix() {
    echo -e "${YELLOW}是否需要尝试自动修复？(y/N): ${NC}"
    read -p "" auto_fix
    
    if [[ $auto_fix =~ ^[Yy]$ ]]; then
        log_info "开始自动修复..."
        
        # 重启WireGuard服务
        echo "重启WireGuard服务..."
        systemctl restart wg-quick@$WG_INTERFACE
        
        # 重新加载iptables规则
        if [[ -f $FORWARD_RULES_FILE ]]; then
            echo "重新添加iptables规则..."
            while IFS=':' read -r public_port client_name client_ip target_port service_name create_time; do
                # 删除可能存在的旧规则
                iptables -t nat -D PREROUTING -p tcp --dport "$public_port" -j DNAT --to-destination "$client_ip:$target_port" 2>/dev/null || true
                iptables -D FORWARD -p tcp -d "$client_ip" --dport "$target_port" -j ACCEPT 2>/dev/null || true
                iptables -D INPUT -p tcp --dport "$public_port" -j ACCEPT 2>/dev/null || true
                
                # 添加新规则
                iptables -t nat -A PREROUTING -p tcp --dport "$public_port" -j DNAT --to-destination "$client_ip:$target_port"
                iptables -A FORWARD -p tcp -d "$client_ip" --dport "$target_port" -j ACCEPT
                iptables -A INPUT -p tcp --dport "$public_port" -j ACCEPT
                
                echo "  重新添加规则: $public_port → $client_ip:$target_port"
            done < "$FORWARD_RULES_FILE"
            
            # 保存规则
            if command -v iptables-save >/dev/null 2>&1; then
                iptables-save > /etc/iptables/rules.v4 2>/dev/null || true
            fi
        fi
        
        log_success "自动修复完成，请重新测试连接"
    fi
}

# 主函数
main() {
    show_banner
    check_root
    
    log_info "开始WireGuard端口转发故障排查..."
    echo ""
    
    # 执行所有检查
    check_wireguard_service
    check_server_public_ip
    check_port_forward_rules
    check_iptables_rules
    check_client_status
    check_port_listening
    test_external_connection
    check_system_firewall
    
    # 生成修复建议
    generate_fix_suggestions
    
    # 交互式修复
    interactive_fix
    
    echo ""
    log_info "故障排查完成！"
    echo ""
    echo "如果问题仍然存在，请："
    echo "1. 检查VPS提供商的安全组设置"
    echo "2. 确认Windows客户端防火墙配置"
    echo "3. 验证目标服务是否正确运行"
    echo "4. 尝试从不同网络环境测试连接"
}

# 脚本入口
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
