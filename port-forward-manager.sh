#!/bin/bash
# -*- coding: utf-8 -*-

# WireGuard端口转发管理脚本
# 通过服务端公网IP远程访问客户端
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

# 显示横幅
show_banner() {
    clear
    echo -e "${CYAN}"
    cat << "EOF"
╔══════════════════════════════════════════════════════════════╗
║                WireGuard端口转发管理器                        ║
║                                                              ║
║  🎯 功能:                                                     ║
║  • 通过服务端公网IP访问客户端                                  ║
║  • 支持RDP、SSH、HTTP等服务                                   ║
║  • 动态添加/删除端口转发规则                                   ║
║  • 自动防火墙配置                                              ║
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

# 检查WireGuard是否运行
check_wireguard() {
    if ! systemctl is-active --quiet wg-quick@$WG_INTERFACE; then
        log_error "WireGuard服务未运行"
        echo "请先启动WireGuard服务: sudo systemctl start wg-quick@$WG_INTERFACE"
        exit 1
    fi
    log_info "WireGuard服务运行正常"
}

# 获取客户端列表
get_client_list() {
    local clients=()
    local client_dir="$WG_CONFIG_DIR/clients"
    
    if [[ -d $client_dir ]]; then
        for config_file in "$client_dir"/*.conf; do
            if [[ -f $config_file ]]; then
                local client_name=$(basename "$config_file" .conf)
                local client_ip=$(grep "Address" "$config_file" | cut -d'=' -f2 | cut -d'/' -f1 | tr -d ' ')
                
                # 检查客户端是否在线
                if wg show | grep -q "$client_ip"; then
                    clients+=("$client_name:$client_ip:在线")
                else
                    clients+=("$client_name:$client_ip:离线")
                fi
            fi
        done
    fi
    
    echo "${clients[@]}"
}

# 检查端口是否被占用
check_port_usage() {
    local port=$1
    if ss -tulpn | grep ":$port " >/dev/null 2>&1; then
        return 1
    fi
    return 0
}

# 添加端口转发规则
add_port_forward() {
    log_info "添加端口转发规则..."
    
    # 获取客户端列表
    local clients=($(get_client_list))
    if [[ ${#clients[@]} -eq 0 ]]; then
        log_error "没有找到客户端配置"
        return 1
    fi
    
    echo ""
    echo "可用的客户端："
    local i=1
    for client in "${clients[@]}"; do
        IFS=':' read -r name ip status <<< "$client"
        if [[ $status == "在线" ]]; then
            echo -e "$i. ${GREEN}$name${NC} ($ip) - $status"
        else
            echo -e "$i. ${RED}$name${NC} ($ip) - $status"
        fi
        ((i++))
    done
    
    echo ""
    read -p "请选择要转发到的客户端编号: " client_choice
    
    if [[ ! $client_choice =~ ^[0-9]+$ ]] || [[ $client_choice -lt 1 ]] || [[ $client_choice -gt ${#clients[@]} ]]; then
        log_error "无效的客户端选择"
        return 1
    fi
    
    local selected_client="${clients[$((client_choice-1))]}"
    IFS=':' read -r client_name client_ip client_status <<< "$selected_client"
    
    if [[ $client_status == "离线" ]]; then
        log_warn "警告: 选择的客户端当前离线"
        read -p "是否继续添加转发规则？(y/N): " continue_offline
        if [[ ! $continue_offline =~ ^[Yy]$ ]]; then
            return 1
        fi
    fi
    
    echo ""
    echo "常用服务端口："
    echo "1. RDP (远程桌面) - 3389"
    echo "2. SSH - 22"
    echo "3. HTTP - 80"
    echo "4. HTTPS - 443"
    echo "5. FTP - 21"
    echo "6. 自定义端口"
    echo ""
    
    read -p "请选择服务类型 (1-6): " service_choice
    
    local target_port=""
    local service_name=""
    
    case $service_choice in
        1)
            target_port="3389"
            service_name="RDP"
            ;;
        2)
            target_port="22"
            service_name="SSH"
            ;;
        3)
            target_port="80"
            service_name="HTTP"
            ;;
        4)
            target_port="443"
            service_name="HTTPS"
            ;;
        5)
            target_port="21"
            service_name="FTP"
            ;;
        6)
            read -p "请输入目标端口: " target_port
            read -p "请输入服务名称: " service_name
            ;;
        *)
            log_error "无效的服务类型选择"
            return 1
            ;;
    esac
    
    if [[ ! $target_port =~ ^[0-9]+$ ]] || [[ $target_port -lt 1 ]] || [[ $target_port -gt 65535 ]]; then
        log_error "无效的端口号"
        return 1
    fi
    
    # 选择公网端口
    local public_port=""
    read -p "请输入公网端口 (默认与目标端口相同: $target_port): " public_port
    public_port=${public_port:-$target_port}
    
    if [[ ! $public_port =~ ^[0-9]+$ ]] || [[ $public_port -lt 1 ]] || [[ $public_port -gt 65535 ]]; then
        log_error "无效的公网端口号"
        return 1
    fi
    
    # 检查公网端口是否被占用
    if ! check_port_usage "$public_port"; then
        log_error "公网端口 $public_port 已被占用"
        return 1
    fi
    
    # 添加iptables规则
    log_info "添加iptables转发规则..."
    
    # DNAT规则 - 将公网端口转发到客户端
    iptables -t nat -A PREROUTING -p tcp --dport "$public_port" -j DNAT --to-destination "$client_ip:$target_port"
    
    # FORWARD规则 - 允许转发
    iptables -A FORWARD -p tcp -d "$client_ip" --dport "$target_port" -j ACCEPT
    iptables -A FORWARD -p tcp -s "$client_ip" --sport "$target_port" -j ACCEPT
    
    # INPUT规则 - 允许公网端口访问
    iptables -A INPUT -p tcp --dport "$public_port" -j ACCEPT
    
    # 保存规则到配置文件
    mkdir -p "$(dirname "$FORWARD_RULES_FILE")"
    echo "$public_port:$client_name:$client_ip:$target_port:$service_name:$(date)" >> "$FORWARD_RULES_FILE"
    
    # 保存iptables规则
    if command -v iptables-save >/dev/null 2>&1; then
        iptables-save > /etc/iptables/rules.v4 2>/dev/null || true
    fi
    
    log_success "端口转发规则添加成功！"
    echo ""
    echo -e "${CYAN}转发规则信息：${NC}"
    echo "服务名称: $service_name"
    echo "客户端: $client_name ($client_ip)"
    echo "公网端口: $public_port"
    echo "目标端口: $target_port"
    echo ""
    echo -e "${YELLOW}访问方式：${NC}"
    
    # 获取服务端公网IP
    local server_ip=$(curl -s http://ipv4.icanhazip.com 2>/dev/null || curl -s http://members.3322.org/dyndns/getip 2>/dev/null)
    
    if [[ $service_name == "RDP" ]]; then
        echo "远程桌面连接: $server_ip:$public_port"
        echo "或在远程桌面客户端中输入: $server_ip:$public_port"
    elif [[ $service_name == "SSH" ]]; then
        echo "SSH连接: ssh user@$server_ip -p $public_port"
    elif [[ $service_name == "HTTP" ]]; then
        echo "HTTP访问: http://$server_ip:$public_port"
    elif [[ $service_name == "HTTPS" ]]; then
        echo "HTTPS访问: https://$server_ip:$public_port"
    else
        echo "访问地址: $server_ip:$public_port"
    fi
}

# 列出端口转发规则
list_port_forwards() {
    log_info "当前端口转发规则："
    
    if [[ ! -f $FORWARD_RULES_FILE ]] || [[ ! -s $FORWARD_RULES_FILE ]]; then
        echo "暂无端口转发规则"
        return
    fi
    
    echo ""
    printf "%-8s %-15s %-15s %-8s %-10s %-20s\n" "公网端口" "客户端名称" "客户端IP" "目标端口" "服务" "创建时间"
    echo "=================================================================================="
    
    while IFS=':' read -r public_port client_name client_ip target_port service_name create_time; do
        # 检查客户端是否在线
        local status="离线"
        if wg show | grep -q "$client_ip"; then
            status="在线"
        fi
        
        if [[ $status == "在线" ]]; then
            printf "%-8s %-15s ${GREEN}%-15s${NC} %-8s %-10s %-20s\n" "$public_port" "$client_name" "$client_ip" "$target_port" "$service_name" "$create_time"
        else
            printf "%-8s %-15s ${RED}%-15s${NC} %-8s %-10s %-20s\n" "$public_port" "$client_name" "$client_ip" "$target_port" "$service_name" "$create_time"
        fi
    done < "$FORWARD_RULES_FILE"
    
    echo ""
    
    # 显示访问信息
    local server_ip=$(curl -s http://ipv4.icanhazip.com 2>/dev/null || curl -s http://members.3322.org/dyndns/getip 2>/dev/null)
    echo -e "${CYAN}服务端公网IP: $server_ip${NC}"
    echo "通过 服务端IP:公网端口 访问对应的客户端服务"
}

# 删除端口转发规则
remove_port_forward() {
    log_info "删除端口转发规则..."
    
    if [[ ! -f $FORWARD_RULES_FILE ]] || [[ ! -s $FORWARD_RULES_FILE ]]; then
        log_warn "暂无端口转发规则可删除"
        return
    fi
    
    echo ""
    echo "现有端口转发规则："
    local rules=()
    local i=1
    
    while IFS=':' read -r public_port client_name client_ip target_port service_name create_time; do
        rules+=("$public_port:$client_name:$client_ip:$target_port:$service_name:$create_time")
        echo "$i. $service_name - $client_name ($client_ip) - 公网端口:$public_port -> 目标端口:$target_port"
        ((i++))
    done < "$FORWARD_RULES_FILE"
    
    echo ""
    read -p "请选择要删除的规则编号: " rule_choice
    
    if [[ ! $rule_choice =~ ^[0-9]+$ ]] || [[ $rule_choice -lt 1 ]] || [[ $rule_choice -gt ${#rules[@]} ]]; then
        log_error "无效的规则选择"
        return 1
    fi
    
    local selected_rule="${rules[$((rule_choice-1))]}"
    IFS=':' read -r public_port client_name client_ip target_port service_name create_time <<< "$selected_rule"
    
    # 确认删除
    echo ""
    echo "将要删除的规则："
    echo "服务: $service_name"
    echo "客户端: $client_name ($client_ip)"
    echo "公网端口: $public_port -> 目标端口: $target_port"
    echo ""
    
    read -p "确认删除此规则？(y/N): " confirm
    if [[ ! $confirm =~ ^[Yy]$ ]]; then
        log_info "取消删除"
        return
    fi
    
    # 删除iptables规则
    log_info "删除iptables规则..."
    
    iptables -t nat -D PREROUTING -p tcp --dport "$public_port" -j DNAT --to-destination "$client_ip:$target_port" 2>/dev/null || true
    iptables -D FORWARD -p tcp -d "$client_ip" --dport "$target_port" -j ACCEPT 2>/dev/null || true
    iptables -D FORWARD -p tcp -s "$client_ip" --sport "$target_port" -j ACCEPT 2>/dev/null || true
    iptables -D INPUT -p tcp --dport "$public_port" -j ACCEPT 2>/dev/null || true
    
    # 从配置文件中删除规则
    local temp_file=$(mktemp)
    grep -v "^$public_port:$client_name:$client_ip:$target_port:$service_name:" "$FORWARD_RULES_FILE" > "$temp_file" || true
    mv "$temp_file" "$FORWARD_RULES_FILE"
    
    # 保存iptables规则
    if command -v iptables-save >/dev/null 2>&1; then
        iptables-save > /etc/iptables/rules.v4 2>/dev/null || true
    fi
    
    log_success "端口转发规则删除成功！"
}

# 显示使用说明
show_usage_guide() {
    echo -e "${CYAN}=== 端口转发使用指南 ===${NC}"
    echo ""
    echo "1. 📋 工作原理："
    echo "   服务端公网IP:公网端口 -> WireGuard客户端IP:目标端口"
    echo ""
    echo "2. 🔧 常用场景："
    echo "   • RDP远程桌面: 公网端口3389 -> Windows客户端3389"
    echo "   • SSH远程登录: 公网端口22 -> Linux客户端22"
    echo "   • Web服务访问: 公网端口80 -> 客户端80"
    echo ""
    echo "3. 🛡️ 安全建议："
    echo "   • 使用非标准端口（如RDP使用13389而不是3389）"
    echo "   • 定期更改端口转发规则"
    echo "   • 监控访问日志"
    echo "   • 使用强密码和密钥认证"
    echo ""
    echo "4. 🔍 故障排查："
    echo "   • 确保客户端在线"
    echo "   • 检查客户端防火墙设置"
    echo "   • 验证目标服务是否运行"
    echo "   • 测试网络连通性"
    echo ""
}

# 显示主菜单
show_main_menu() {
    clear
    show_banner
    
    echo -e "${WHITE}请选择操作：${NC}"
    echo ""
    echo "1. 添加端口转发规则"
    echo "2. 列出端口转发规则"
    echo "3. 删除端口转发规则"
    echo "4. 显示使用指南"
    echo "0. 退出"
    echo ""
}

# 主函数
main() {
    check_root
    check_wireguard
    
    while true; do
        show_main_menu
        read -p "请选择操作 (0-4): " choice
        
        case $choice in
            1)
                add_port_forward
                read -p "按回车键继续..."
                ;;
            2)
                list_port_forwards
                read -p "按回车键继续..."
                ;;
            3)
                remove_port_forward
                read -p "按回车键继续..."
                ;;
            4)
                show_usage_guide
                read -p "按回车键继续..."
                ;;
            0)
                log_info "感谢使用WireGuard端口转发管理器！"
                exit 0
                ;;
            *)
                log_error "无效的选项"
                read -p "按回车键继续..."
                ;;
        esac
    done
}

# 脚本入口
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
