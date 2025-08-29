#!/bin/bash
# -*- coding: utf-8 -*-

# WireGuard服务端Windows客户端优化脚本
# 专门针对Windows客户端远程访问进行服务端优化
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
║            WireGuard Windows客户端优化工具                   ║
║                                                              ║
║  🎯 专门优化:                                                 ║
║  • Windows客户端连接稳定性                                    ║
║  • 远程访问性能优化                                            ║
║  • 网络延迟和丢包优化                                          ║
║  • 防火墙和路由优化                                            ║
║  • DNS解析优化                                                ║
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

# 检查WireGuard是否已安装
check_wireguard_installed() {
    if [[ ! -f "$WG_CONFIG_DIR/$WG_INTERFACE.conf" ]]; then
        log_error "WireGuard服务端未安装"
        echo "请先运行主安装脚本安装WireGuard服务端"
        exit 1
    fi
    log_info "检测到WireGuard服务端已安装"
}

# 优化系统内核参数
optimize_kernel_parameters() {
    log_info "优化系统内核参数..."
    
    # 备份原始配置
    cp /etc/sysctl.conf /etc/sysctl.conf.backup.$(date +%Y%m%d) 2>/dev/null || true
    
    # 添加Windows客户端优化参数
    cat >> /etc/sysctl.conf << 'EOF'

# ===== WireGuard Windows客户端优化参数 =====
# 网络缓冲区优化
net.core.rmem_max = 268435456
net.core.wmem_max = 268435456
net.core.rmem_default = 262144
net.core.wmem_default = 262144

# UDP优化（WireGuard使用UDP）
net.ipv4.udp_mem = 102400 873800 16777216
net.ipv4.udp_rmem_min = 16384
net.ipv4.udp_wmem_min = 16384

# 减少网络延迟
net.ipv4.tcp_low_latency = 1
net.ipv4.tcp_frto = 2
net.ipv4.tcp_mtu_probing = 1

# 网络队列优化
net.core.netdev_max_backlog = 30000
net.core.netdev_budget = 600
net.core.netdev_budget_usecs = 5000

# 连接跟踪优化
net.netfilter.nf_conntrack_max = 1000000
net.netfilter.nf_conntrack_buckets = 250000
net.netfilter.nf_conntrack_tcp_timeout_established = 1200
net.netfilter.nf_conntrack_udp_timeout = 60
net.netfilter.nf_conntrack_udp_timeout_stream = 120

# IPv4转发和路由优化
net.ipv4.ip_forward = 1
net.ipv4.conf.all.forwarding = 1
net.ipv4.conf.default.forwarding = 1
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0

# 防止IP欺骗
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1

# 优化TCP窗口缩放
net.ipv4.tcp_window_scaling = 1
net.ipv4.tcp_timestamps = 1
net.ipv4.tcp_sack = 1
net.ipv4.tcp_fack = 1

# 内存和文件句柄优化
fs.file-max = 1000000
fs.nr_open = 1000000
EOF
    
    # 应用参数
    sysctl -p >/dev/null 2>&1 || log_warn "部分参数应用失败"
    
    log_success "内核参数优化完成"
}

# 优化WireGuard配置
optimize_wireguard_config() {
    log_info "优化WireGuard服务端配置..."
    
    local config_file="$WG_CONFIG_DIR/$WG_INTERFACE.conf"
    local temp_file=$(mktemp)
    
    # 读取现有配置并优化
    while IFS= read -r line; do
        if [[ $line =~ ^PostUp ]]; then
            # 优化PostUp规则，添加更多iptables优化
            echo "$line" >> "$temp_file"
            echo "PostUp = echo 1 > /proc/sys/net/ipv4/ip_forward" >> "$temp_file"
            echo "PostUp = iptables -A INPUT -i %i -j ACCEPT" >> "$temp_file"
            echo "PostUp = iptables -A OUTPUT -o %i -j ACCEPT" >> "$temp_file"
        elif [[ $line =~ ^PostDown ]]; then
            # 优化PostDown规则
            echo "$line" >> "$temp_file"
            echo "PostDown = iptables -D INPUT -i %i -j ACCEPT" >> "$temp_file"
            echo "PostDown = iptables -D OUTPUT -o %i -j ACCEPT" >> "$temp_file"
        else
            echo "$line" >> "$temp_file"
        fi
    done < "$config_file"
    
    # 替换配置文件
    mv "$temp_file" "$config_file"
    chmod 600 "$config_file"
    
    log_success "WireGuard配置优化完成"
}

# 优化防火墙规则
optimize_firewall_rules() {
    log_info "优化防火墙规则..."
    
    # 获取WireGuard端口
    local wg_port=$(grep "ListenPort" "$WG_CONFIG_DIR/$WG_INTERFACE.conf" | cut -d'=' -f2 | tr -d ' ')
    local wg_subnet=$(grep "Address" "$WG_CONFIG_DIR/$WG_INTERFACE.conf" | cut -d'=' -f2 | tr -d ' ' | cut -d'/' -f1 | cut -d'.' -f1-3)
    
    # 优化iptables规则
    log_info "添加优化的iptables规则..."
    
    # 允许WireGuard流量
    iptables -I INPUT -p udp --dport "$wg_port" -j ACCEPT 2>/dev/null || true
    iptables -I INPUT -i "$WG_INTERFACE" -j ACCEPT 2>/dev/null || true
    iptables -I OUTPUT -o "$WG_INTERFACE" -j ACCEPT 2>/dev/null || true
    
    # 优化转发规则
    iptables -I FORWARD -i "$WG_INTERFACE" -j ACCEPT 2>/dev/null || true
    iptables -I FORWARD -o "$WG_INTERFACE" -j ACCEPT 2>/dev/null || true
    iptables -I FORWARD -i "$WG_INTERFACE" -o "$WG_INTERFACE" -j ACCEPT 2>/dev/null || true
    
    # 优化NAT规则
    iptables -t nat -I POSTROUTING -s "${wg_subnet}.0/24" -j MASQUERADE 2>/dev/null || true
    
    # 优化连接跟踪
    iptables -I INPUT -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT 2>/dev/null || true
    iptables -I FORWARD -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT 2>/dev/null || true
    
    # 防止DDoS攻击
    iptables -I INPUT -p udp --dport "$wg_port" -m conntrack --ctstate NEW -m recent --set 2>/dev/null || true
    iptables -I INPUT -p udp --dport "$wg_port" -m conntrack --ctstate NEW -m recent --update --seconds 60 --hitcount 10 -j DROP 2>/dev/null || true
    
    log_success "防火墙规则优化完成"
}

# 优化网络接口
optimize_network_interface() {
    log_info "优化网络接口参数..."
    
    # 获取主网络接口
    local main_interface=$(ip route | grep default | awk '{print $5}' | head -n1)
    
    if [[ -n $main_interface ]]; then
        log_info "优化主网络接口: $main_interface"
        
        # 设置网络接口队列长度
        ip link set dev "$main_interface" txqueuelen 10000 2>/dev/null || true
        
        # 启用网络接口的各种优化特性
        if command -v ethtool >/dev/null 2>&1; then
            ethtool -K "$main_interface" rx on tx on sg on tso on gso on gro on 2>/dev/null || true
            ethtool -G "$main_interface" rx 4096 tx 4096 2>/dev/null || true
        fi
        
        log_success "网络接口优化完成"
    else
        log_warn "无法检测到主网络接口"
    fi
}

# 创建Windows客户端配置模板
create_windows_client_template() {
    log_info "创建Windows客户端配置模板..."
    
    local template_dir="$WG_CONFIG_DIR/templates"
    mkdir -p "$template_dir"
    
    # 获取服务端信息
    local server_public_key=$(grep "PrivateKey" "$WG_CONFIG_DIR/$WG_INTERFACE.conf" | cut -d'=' -f2 | tr -d ' ' | wg pubkey)
    local server_port=$(grep "ListenPort" "$WG_CONFIG_DIR/$WG_INTERFACE.conf" | cut -d'=' -f2 | tr -d ' ')
    local server_ip=$(curl -s http://ipv4.icanhazip.com 2>/dev/null || curl -s http://members.3322.org/dyndns/getip 2>/dev/null)
    
    # 创建Windows客户端配置模板
    cat > "$template_dir/windows-client-template.conf" << EOF
[Interface]
# Windows客户端私钥（需要生成）
PrivateKey = CLIENT_PRIVATE_KEY_HERE
# 客户端IP地址（需要分配）
Address = CLIENT_IP_HERE/24
# 优化的DNS设置
DNS = 223.5.5.5, 119.29.29.29, 8.8.8.8
# Windows客户端MTU优化
MTU = 1420

[Peer]
# 服务端公钥
PublicKey = $server_public_key
# 服务端地址和端口
Endpoint = $server_ip:$server_port
# 允许所有流量通过VPN（全局代理）
AllowedIPs = 0.0.0.0/0
# 保持连接活跃（重要：防止NAT超时）
PersistentKeepalive = 25
EOF
    
    # 创建部分流量路由模板（仅代理特定网段）
    cat > "$template_dir/windows-client-partial.conf" << EOF
[Interface]
# Windows客户端私钥（需要生成）
PrivateKey = CLIENT_PRIVATE_KEY_HERE
# 客户端IP地址（需要分配）
Address = CLIENT_IP_HERE/24
# 优化的DNS设置
DNS = 223.5.5.5, 119.29.29.29
# Windows客户端MTU优化
MTU = 1420

[Peer]
# 服务端公钥
PublicKey = $server_public_key
# 服务端地址和端口
Endpoint = $server_ip:$server_port
# 仅代理服务端内网（用于远程访问服务端资源）
AllowedIPs = \$PRIVATE_SUBNET, 192.168.0.0/16, 172.16.0.0/12
# 保持连接活跃
PersistentKeepalive = 25
EOF
    
    log_success "Windows客户端配置模板创建完成"
    echo "模板位置: $template_dir/"
}

# 创建客户端管理脚本
create_client_management_script() {
    log_info "创建Windows客户端管理脚本..."
    
    cat > "/usr/local/bin/wg-windows-client" << 'EOF'
#!/bin/bash

# WireGuard Windows客户端管理脚本

WG_CONFIG_DIR="/etc/wireguard"
WG_INTERFACE="wg0"

# 颜色定义
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 生成Windows客户端配置
generate_windows_client() {
    local client_name=$1
    local client_type=${2:-full}  # full 或 partial
    
    if [[ -z $client_name ]]; then
        echo "用法: $0 generate <客户端名称> [full|partial]"
        echo "  full: 全局代理（默认）"
        echo "  partial: 仅访问内网资源"
        exit 1
    fi
    
    # 生成客户端密钥
    local client_private_key=$(wg genkey)
    local client_public_key=$(echo "$client_private_key" | wg pubkey)
    
    # 获取服务端信息
    local server_public_key=$(grep "PrivateKey" "$WG_CONFIG_DIR/$WG_INTERFACE.conf" | cut -d'=' -f2 | tr -d ' ' | wg pubkey)
    local server_port=$(grep "ListenPort" "$WG_CONFIG_DIR/$WG_INTERFACE.conf" | cut -d'=' -f2 | tr -d ' ')
    local server_ip=$(curl -s http://ipv4.icanhazip.com 2>/dev/null || curl -s http://members.3322.org/dyndns/getip 2>/dev/null)
    
    # 分配客户端IP
    local server_subnet=$(grep "Address" "$WG_CONFIG_DIR/$WG_INTERFACE.conf" | cut -d'=' -f2 | tr -d ' ')
    local subnet_base=$(echo "$server_subnet" | cut -d'/' -f1 | cut -d'.' -f1-3)
    local client_ip=""
    
    for i in {2..254}; do
        local test_ip="$subnet_base.$i"
        if ! grep -q "$test_ip" "$WG_CONFIG_DIR/$WG_INTERFACE.conf" 2>/dev/null; then
            client_ip="$test_ip"
            break
        fi
    done
    
    if [[ -z $client_ip ]]; then
        log_error "没有可用的IP地址"
        exit 1
    fi
    
    # 创建客户端配置目录
    mkdir -p "$WG_CONFIG_DIR/clients"
    
    # 生成客户端配置
    local config_file="$WG_CONFIG_DIR/clients/${client_name}-windows.conf"
    
    if [[ $client_type == "partial" ]]; then
        # 部分流量路由配置
        cat > "$config_file" << CONF
[Interface]
PrivateKey = $client_private_key
Address = $client_ip/24
DNS = 223.5.5.5, 119.29.29.29
MTU = 1420

[Peer]
PublicKey = $server_public_key
Endpoint = $server_ip:$server_port
AllowedIPs = $server_subnet, 192.168.0.0/16, 172.16.0.0/12
PersistentKeepalive = 25
CONF
    else
        # 全局代理配置
        cat > "$config_file" << CONF
[Interface]
PrivateKey = $client_private_key
Address = $client_ip/24
DNS = 223.5.5.5, 119.29.29.29, 8.8.8.8
MTU = 1420

[Peer]
PublicKey = $server_public_key
Endpoint = $server_ip:$server_port
AllowedIPs = 0.0.0.0/0
PersistentKeepalive = 25
CONF
    fi
    
    # 添加客户端到服务端配置
    cat >> "$WG_CONFIG_DIR/$WG_INTERFACE.conf" << CONF

# Windows Client: $client_name
[Peer]
PublicKey = $client_public_key
AllowedIPs = $client_ip/32
CONF
    
    # 重启WireGuard服务
    systemctl restart wg-quick@$WG_INTERFACE
    
    log_info "Windows客户端 $client_name 配置生成完成"
    log_info "配置文件: $config_file"
    log_info "客户端IP: $client_ip"
    
    # 生成二维码
    if command -v qrencode >/dev/null 2>&1; then
        echo ""
        log_info "配置二维码："
        qrencode -t ansiutf8 < "$config_file"
    fi
    
    echo ""
    echo "配置内容："
    cat "$config_file"
}

# 主函数
case "${1:-}" in
    generate)
        generate_windows_client "$2" "$3"
        ;;
    *)
        echo "WireGuard Windows客户端管理工具"
        echo ""
        echo "用法:"
        echo "  $0 generate <客户端名称> [full|partial]"
        echo ""
        echo "示例:"
        echo "  $0 generate laptop full      # 生成全局代理配置"
        echo "  $0 generate office partial   # 生成内网访问配置"
        ;;
esac
EOF
    
    chmod +x "/usr/local/bin/wg-windows-client"
    log_success "Windows客户端管理脚本创建完成"
    echo "使用方法: wg-windows-client generate <客户端名称> [full|partial]"
}

# 显示优化建议
show_optimization_tips() {
    echo ""
    echo -e "${CYAN}=== Windows客户端使用建议 ===${NC}"
    echo ""
    echo "1. 📱 客户端软件推荐："
    echo "   • 官方客户端: https://www.wireguard.com/install/"
    echo "   • 或使用: winget install WireGuard.WireGuard"
    echo ""
    echo "2. 🔧 Windows客户端优化："
    echo "   • 以管理员身份运行WireGuard客户端"
    echo "   • 在Windows防火墙中允许WireGuard"
    echo "   • 禁用IPv6（如果不需要）"
    echo "   • 设置DNS为自动获取"
    echo ""
    echo "3. 🌐 连接类型选择："
    echo "   • 全局代理(full): 所有流量通过VPN"
    echo "   • 内网访问(partial): 仅访问服务端内网资源"
    echo ""
    echo "4. 🔍 故障排查："
    echo "   • 检查Windows时间同步"
    echo "   • 确认服务端防火墙端口开放"
    echo "   • 使用ping测试连通性"
    echo "   • 检查MTU设置（建议1420）"
    echo ""
    echo "5. 📊 性能优化："
    echo "   • 使用有线网络连接"
    echo "   • 关闭不必要的Windows服务"
    echo "   • 更新网卡驱动程序"
    echo ""
}

# 主函数
main() {
    show_banner
    check_root
    check_wireguard_installed
    
    echo "开始优化WireGuard服务端以支持Windows客户端..."
    echo ""
    
    optimize_kernel_parameters
    optimize_wireguard_config
    optimize_firewall_rules
    optimize_network_interface
    create_windows_client_template
    create_client_management_script
    
    # 重启WireGuard服务应用优化
    log_info "重启WireGuard服务应用优化..."
    systemctl restart wg-quick@$WG_INTERFACE
    
    if systemctl is-active --quiet wg-quick@$WG_INTERFACE; then
        log_success "WireGuard服务重启成功"
    else
        log_error "WireGuard服务重启失败"
        exit 1
    fi
    
    echo ""
    log_success "🎉 Windows客户端优化完成！"
    echo ""
    echo "现在可以生成Windows客户端配置："
    echo "wg-windows-client generate laptop full      # 全局代理"
    echo "wg-windows-client generate office partial   # 内网访问"
    
    show_optimization_tips
    
    echo ""
    echo "建议重启服务器以确保所有优化生效："
    echo "sudo reboot"
}

# 脚本入口
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
