#!/bin/bash
# -*- coding: utf-8 -*-

# WireGuard 一体化安装脚本
# 集成所有功能于单个脚本，无需额外依赖
# 版本: 2.0.0
# 作者: WireGuard安装助手

# 设置UTF-8编码环境
export LANG=C.UTF-8
export LC_ALL=C.UTF-8

# 调试模式
DEBUG_MODE=${DEBUG_MODE:-false}

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m'

# 全局变量
SCRIPT_VERSION="2.0.0"
WG_CONFIG_DIR="/etc/wireguard"
WG_INTERFACE="wg0"
WG_PORT="51820"
SERVER_PRIVATE_KEY=""
SERVER_PUBLIC_KEY=""
CLIENT_COUNT=0
IS_CHINA_NETWORK=false
SYSTEM_TYPE=""
ARCH=""
SERVER_IP=""
PRIVATE_SUBNET="10.66.0.0/16"
PRIVATE_SUBNET_IP="10.66.0.1"
DNS_SERVERS="8.8.8.8,8.8.4.4"

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

log_debug() {
    if [[ $DEBUG_MODE == true ]]; then
        echo -e "${BLUE}[DEBUG]${NC} $1"
    fi
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
║                WireGuard 一体化安装脚本                       ║
║                                                              ║
║  🚀 功能特性:                                                 ║
║  • 完全交互式安装界面                                          ║
║  • 国内外网络环境自动适配                                      ║
║  • 智能网络优化配置                                            ║
║  • 批量客户端管理                                              ║
║  • 系统监控和故障诊断                                          ║
║  • 配置备份和恢复                                              ║
║  • 单文件集成，无需额外依赖                                    ║
║                                                              ║
╚══════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
    echo -e "${WHITE}版本: ${SCRIPT_VERSION} | 一体化版本${NC}"
    echo ""
}

# 错误处理
handle_error() {
    local exit_code=$?
    local line_number=$1
    log_error "脚本在第 $line_number 行出错，退出码: $exit_code"
    log_error "如需帮助，请运行: DEBUG_MODE=true $0"
    exit $exit_code
}

trap 'handle_error $LINENO' ERR

# 检查root权限
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "此脚本需要root权限运行"
        echo "请使用: sudo $0"
        exit 1
    fi
}

# 检测系统类型
detect_system() {
    log_info "检测系统环境..."
    
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        SYSTEM_TYPE=$ID
    elif [[ -f /etc/redhat-release ]]; then
        SYSTEM_TYPE="centos"
    elif [[ -f /etc/debian_version ]]; then
        SYSTEM_TYPE="debian"
    else
        log_error "不支持的操作系统"
        exit 1
    fi
    
    ARCH=$(uname -m)
    log_info "检测到系统: $SYSTEM_TYPE ($ARCH)"
}

# 智能网络环境检测
detect_network_environment() {
    log_info "检测网络环境..."
    
    local china_indicators=0
    local total_tests=0
    
    # 检查时区
    ((total_tests++))
    if [[ -f /etc/timezone ]]; then
        local timezone=$(cat /etc/timezone 2>/dev/null || echo "")
        if [[ $timezone =~ Asia/Shanghai|Asia/Beijing|Asia/Chongqing ]]; then
            ((china_indicators++))
            log_debug "时区指示国内环境: $timezone"
        fi
    fi
    
    # 检查语言环境
    ((total_tests++))
    if [[ $LANG =~ zh_CN|zh_TW ]]; then
        ((china_indicators++))
        log_debug "语言环境指示中文: $LANG"
    fi
    
    # 简单的网络测试
    ((total_tests++))
    if timeout 3 ping -c 1 -W 1 223.5.5.5 >/dev/null 2>&1; then
        ((china_indicators++))
        log_debug "阿里DNS连通，可能是国内网络"
    fi
    
    # DNS查询测试
    ((total_tests++))
    if command -v nslookup >/dev/null 2>&1; then
        if timeout 3 nslookup baidu.com >/dev/null 2>&1; then
            ((china_indicators++))
            log_debug "百度域名解析成功"
        fi
    fi
    
    # 根据指标判断网络环境
    if [[ $china_indicators -gt $((total_tests / 2)) ]]; then
        IS_CHINA_NETWORK=true
        log_info "检测到国内网络环境 ($china_indicators/$total_tests 指标)"
        DNS_SERVERS="223.5.5.5,119.29.29.29"
    else
        IS_CHINA_NETWORK=false
        log_info "检测到海外网络环境 ($china_indicators/$total_tests 指标)"
        DNS_SERVERS="8.8.8.8,1.1.1.1"
    fi
}

# 网络连通性测试
test_network_connectivity() {
    log_info "测试网络连通性..."
    
    local test_hosts=("8.8.8.8" "223.5.5.5" "1.1.1.1")
    local success_count=0
    
    for host in "${test_hosts[@]}"; do
        if timeout 2 ping -c 1 -W 1 "$host" >/dev/null 2>&1; then
            ((success_count++))
            log_debug "✓ $host 连通"
            if [[ $success_count -ge 1 ]]; then
                break  # 有一个通就够了
            fi
        fi
    done
    
    if [[ $success_count -eq 0 ]]; then
        log_warn "网络连通性测试失败，但继续安装..."
        log_warn "如果遇到下载问题，请检查网络设置"
    else
        log_info "网络连通性正常"
    fi
}

# 获取服务器公网IP
get_server_ip() {
    log_info "获取服务器公网IP..."
    
    local ip_services=()
    if [[ $IS_CHINA_NETWORK == true ]]; then
        ip_services=(
            "http://members.3322.org/dyndns/getip"
            "http://ip.cip.cc"
            "http://myip.ipip.net"
        )
    else
        ip_services=(
            "http://ipv4.icanhazip.com"
            "http://ifconfig.me/ip"
            "http://api.ipify.org"
        )
    fi
    
    for service in "${ip_services[@]}"; do
        log_debug "尝试从 $service 获取IP"
        SERVER_IP=$(timeout 5 curl -s "$service" 2>/dev/null | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$' | head -n1)
        if [[ -n $SERVER_IP ]]; then
            log_info "服务器公网IP: $SERVER_IP"
            return 0
        fi
    done
    
    log_warn "无法自动获取服务器公网IP"
    while true; do
        read -p "请手动输入服务器公网IP: " SERVER_IP
        if [[ $SERVER_IP =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
            log_info "服务器公网IP设置为: $SERVER_IP"
            break
        else
            log_error "IP地址格式不正确，请重新输入"
        fi
    done
}

# 检查端口占用
check_port_usage() {
    local port=$1
    if command -v ss >/dev/null 2>&1; then
        if ss -tulpn | grep ":$port " >/dev/null 2>&1; then
            return 1
        fi
    elif command -v netstat >/dev/null 2>&1; then
        if netstat -tulpn | grep ":$port " >/dev/null 2>&1; then
            return 1
        fi
    fi
    return 0
}

# 选择WireGuard端口
select_wireguard_port() {
    log_info "配置WireGuard端口..."
    
    while true; do
        read -p "请输入WireGuard端口 (默认: 51820): " input_port
        input_port=${input_port:-51820}
        
        if [[ ! $input_port =~ ^[0-9]+$ ]] || [[ $input_port -lt 1 ]] || [[ $input_port -gt 65535 ]]; then
            log_error "端口必须是1-65535之间的数字"
            continue
        fi
        
        if ! check_port_usage "$input_port"; then
            log_error "端口 $input_port 已被占用，请选择其他端口"
            continue
        fi
        
        WG_PORT=$input_port
        log_info "WireGuard端口设置为: $WG_PORT"
        break
    done
}

# 检查私网段冲突
check_subnet_conflict() {
    local subnet=$1
    local subnet_base=$(echo "$subnet" | cut -d'/' -f1 | cut -d'.' -f1-3)
    
    # 检查是否与现有网络接口冲突
    if ip route | grep -q "$subnet_base" 2>/dev/null; then
        return 1
    fi
    
    # 检查是否与Docker网络冲突
    if command -v docker >/dev/null 2>&1; then
        if docker network ls --format "table {{.Name}}\t{{.Subnet}}" 2>/dev/null | grep -q "$subnet_base"; then
            return 1
        fi
    fi
    
    return 0
}

# 选择私网段
select_private_subnet() {
    log_info "配置私网段..."
    
    local available_subnets=(
        "10.66.0.0/16"
        "10.88.0.0/16" 
        "172.31.0.0/16"
        "192.168.233.0/24"
        "192.168.188.0/24"
    )
    
    echo "可用的私网段："
    for i in "${!available_subnets[@]}"; do
        local subnet="${available_subnets[$i]}"
        if check_subnet_conflict "$subnet"; then
            echo -e "${GREEN}$((i+1)). $subnet (推荐)${NC}"
        else
            echo -e "${RED}$((i+1)). $subnet (冲突)${NC}"
        fi
    done
    
    while true; do
        read -p "请选择私网段 (1-${#available_subnets[@]}, 默认: 1): " choice
        choice=${choice:-1}
        
        if [[ ! $choice =~ ^[0-9]+$ ]] || [[ $choice -lt 1 ]] || [[ $choice -gt ${#available_subnets[@]} ]]; then
            log_error "请输入有效的选项"
            continue
        fi
        
        local selected_subnet="${available_subnets[$((choice-1))]}"
        if ! check_subnet_conflict "$selected_subnet"; then
            log_warn "选择的网段可能存在冲突，是否继续？(y/N)"
            read -p "" confirm
            if [[ ! $confirm =~ ^[Yy]$ ]]; then
                continue
            fi
        fi
        
        PRIVATE_SUBNET="$selected_subnet"
        # 设置服务器IP为网段的第一个IP
        local subnet_base=$(echo "$PRIVATE_SUBNET" | cut -d'/' -f1)
        PRIVATE_SUBNET_IP=$(echo "$subnet_base" | sed 's/\.[0-9]*$/\.1/')
        
        log_info "私网段设置为: $PRIVATE_SUBNET"
        log_info "服务器内网IP: $PRIVATE_SUBNET_IP"
        break
    done
}

# 安装系统依赖
install_dependencies() {
    log_info "安装系统依赖..."

    case $SYSTEM_TYPE in
        ubuntu|debian)
            # 配置国内镜像源
            if [[ $IS_CHINA_NETWORK == true ]]; then
                log_info "配置国内镜像源..."
                cp /etc/apt/sources.list /etc/apt/sources.list.backup 2>/dev/null || true

                if [[ $SYSTEM_TYPE == "ubuntu" ]]; then
                    cat > /etc/apt/sources.list << EOF
deb https://mirrors.aliyun.com/ubuntu/ $(lsb_release -cs) main restricted universe multiverse
deb https://mirrors.aliyun.com/ubuntu/ $(lsb_release -cs)-updates main restricted universe multiverse
deb https://mirrors.aliyun.com/ubuntu/ $(lsb_release -cs)-backports main restricted universe multiverse
deb https://mirrors.aliyun.com/ubuntu/ $(lsb_release -cs)-security main restricted universe multiverse
EOF
                else
                    cat > /etc/apt/sources.list << EOF
deb https://mirrors.aliyun.com/debian/ $(lsb_release -cs) main non-free contrib
deb https://mirrors.aliyun.com/debian/ $(lsb_release -cs)-updates main non-free contrib
deb https://mirrors.aliyun.com/debian/ $(lsb_release -cs)-backports main non-free contrib
deb https://mirrors.aliyun.com/debian-security/ $(lsb_release -cs)-security main non-free contrib
EOF
                fi
            fi

            apt update
            apt install -y wireguard wireguard-tools iptables qrencode curl wget net-tools || {
                log_warn "部分软件包安装失败，尝试基础安装..."
                apt install -y wireguard wireguard-tools iptables curl wget
            }
            ;;

        centos|rhel|fedora)
            if [[ $IS_CHINA_NETWORK == true ]]; then
                log_info "配置国内镜像源..."
                if [[ $SYSTEM_TYPE == "centos" ]]; then
                    sed -e 's|^mirrorlist=|#mirrorlist=|g' \
                        -e 's|^#baseurl=http://mirror.centos.org|baseurl=https://mirrors.aliyun.com|g' \
                        -i.bak /etc/yum.repos.d/CentOS-*.repo 2>/dev/null || true
                fi
            fi

            if command -v dnf >/dev/null 2>&1; then
                dnf install -y epel-release || true
                dnf install -y wireguard-tools iptables qrencode curl wget net-tools || {
                    log_warn "部分软件包安装失败，尝试基础安装..."
                    dnf install -y wireguard-tools iptables curl wget
                }
            else
                yum install -y epel-release || true
                yum install -y wireguard-tools iptables qrencode curl wget net-tools || {
                    log_warn "部分软件包安装失败，尝试基础安装..."
                    yum install -y wireguard-tools iptables curl wget
                }
            fi
            ;;

        *)
            log_error "不支持的系统类型: $SYSTEM_TYPE"
            exit 1
            ;;
    esac

    log_info "依赖安装完成"
}

# 生成密钥对
generate_keys() {
    log_info "生成WireGuard密钥对..."

    # 创建配置目录
    mkdir -p "$WG_CONFIG_DIR"
    chmod 700 "$WG_CONFIG_DIR"

    # 生成服务端密钥
    SERVER_PRIVATE_KEY=$(wg genkey)
    SERVER_PUBLIC_KEY=$(echo "$SERVER_PRIVATE_KEY" | wg pubkey)

    log_info "密钥生成完成"
    log_debug "服务端公钥: $SERVER_PUBLIC_KEY"
}

# 系统优化配置
configure_system_optimization() {
    log_info "配置系统网络优化..."

    # 备份原始配置
    cp /etc/sysctl.conf /etc/sysctl.conf.backup 2>/dev/null || true

    # 启用IP转发
    if ! grep -q "net.ipv4.ip_forward = 1" /etc/sysctl.conf; then
        echo 'net.ipv4.ip_forward = 1' >> /etc/sysctl.conf
    fi
    if ! grep -q "net.ipv6.conf.all.forwarding = 1" /etc/sysctl.conf; then
        echo 'net.ipv6.conf.all.forwarding = 1' >> /etc/sysctl.conf
    fi

    # 针对国内网络的优化
    if [[ $IS_CHINA_NETWORK == true ]]; then
        log_info "应用国内网络优化配置..."

        cat >> /etc/sysctl.conf << 'EOF'

# WireGuard 国内网络优化
net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbr
net.ipv4.tcp_fastopen = 3
net.ipv4.tcp_mtu_probing = 1
net.core.rmem_max = 134217728
net.core.wmem_max = 134217728
net.ipv4.tcp_rmem = 4096 87380 134217728
net.ipv4.tcp_wmem = 4096 65536 134217728
net.ipv4.udp_rmem_min = 8192
net.ipv4.udp_wmem_min = 8192
net.core.netdev_max_backlog = 5000
EOF
    fi

    # 应用系统参数
    sysctl -p >/dev/null 2>&1 || log_warn "部分系统参数应用失败"

    log_info "系统优化配置完成"
}

# 配置防火墙
configure_firewall() {
    log_info "配置防火墙规则..."

    # 检测防火墙类型并配置
    if command -v ufw >/dev/null 2>&1 && ufw status | grep -q "Status: active"; then
        log_info "配置UFW防火墙..."
        ufw allow "$WG_PORT"/udp >/dev/null 2>&1 || log_warn "UFW规则添加失败"
        ufw allow ssh >/dev/null 2>&1 || true
    elif command -v firewall-cmd >/dev/null 2>&1 && systemctl is-active --quiet firewalld; then
        log_info "配置firewalld防火墙..."
        firewall-cmd --permanent --add-port="$WG_PORT"/udp >/dev/null 2>&1 || log_warn "firewalld规则添加失败"
        firewall-cmd --permanent --add-masquerade >/dev/null 2>&1 || true
        firewall-cmd --reload >/dev/null 2>&1 || true
    else
        log_info "配置iptables防火墙..."
        # 添加iptables规则
        iptables -A INPUT -p udp --dport "$WG_PORT" -j ACCEPT 2>/dev/null || log_warn "iptables INPUT规则添加失败"
        iptables -A FORWARD -i "$WG_INTERFACE" -j ACCEPT 2>/dev/null || true
        iptables -A FORWARD -o "$WG_INTERFACE" -j ACCEPT 2>/dev/null || true
        iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE 2>/dev/null || true

        # 尝试保存iptables规则
        if command -v iptables-save >/dev/null 2>&1; then
            iptables-save > /etc/iptables/rules.v4 2>/dev/null || true
        fi
    fi

    log_info "防火墙配置完成"
}

# 创建服务端配置文件
create_server_config() {
    log_info "创建服务端配置文件..."

    cat > "$WG_CONFIG_DIR/$WG_INTERFACE.conf" << EOF
[Interface]
PrivateKey = $SERVER_PRIVATE_KEY
Address = $PRIVATE_SUBNET_IP/$(echo $PRIVATE_SUBNET | cut -d'/' -f2)
ListenPort = $WG_PORT
PostUp = iptables -A FORWARD -i %i -j ACCEPT; iptables -A FORWARD -o %i -j ACCEPT; iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
PostDown = iptables -D FORWARD -i %i -j ACCEPT; iptables -D FORWARD -o %i -j ACCEPT; iptables -t nat -D POSTROUTING -o eth0 -j MASQUERADE

EOF

    chmod 600 "$WG_CONFIG_DIR/$WG_INTERFACE.conf"
    log_info "服务端配置文件创建完成"
}

# 启动WireGuard服务
start_wireguard_service() {
    log_info "启动WireGuard服务..."

    # 启用并启动服务
    systemctl enable wg-quick@$WG_INTERFACE >/dev/null 2>&1 || log_warn "服务启用失败"
    systemctl start wg-quick@$WG_INTERFACE >/dev/null 2>&1 || {
        log_error "WireGuard服务启动失败"
        log_error "请检查配置文件和系统日志"
        systemctl status wg-quick@$WG_INTERFACE --no-pager -l
        return 1
    }

    # 检查服务状态
    if systemctl is-active --quiet wg-quick@$WG_INTERFACE; then
        log_success "WireGuard服务启动成功"
    else
        log_error "WireGuard服务状态异常"
        return 1
    fi
}

# 生成普通客户端配置
generate_client_config() {
    local client_name=$1
    local client_ip=$2

    log_info "为客户端 $client_name 生成配置..."

    # 生成客户端密钥对
    local client_private_key=$(wg genkey)
    local client_public_key=$(echo "$client_private_key" | wg pubkey)

    # 创建客户端配置目录
    local client_dir="$WG_CONFIG_DIR/clients"
    mkdir -p "$client_dir"

    # 生成客户端配置文件
    cat > "$client_dir/$client_name.conf" << EOF
[Interface]
PrivateKey = $client_private_key
Address = $client_ip/$(echo $PRIVATE_SUBNET | cut -d'/' -f2)
DNS = $DNS_SERVERS

[Peer]
PublicKey = $SERVER_PUBLIC_KEY
Endpoint = $SERVER_IP:$WG_PORT
AllowedIPs = 0.0.0.0/0
PersistentKeepalive = 25
EOF

    # 添加客户端到服务端配置
    cat >> "$WG_CONFIG_DIR/$WG_INTERFACE.conf" << EOF
# Client: $client_name
[Peer]
PublicKey = $client_public_key
AllowedIPs = $client_ip/32

EOF

    # 重启WireGuard服务
    systemctl restart wg-quick@$WG_INTERFACE >/dev/null 2>&1 || log_warn "服务重启失败"

    log_info "客户端 $client_name 配置生成完成"

    # 生成二维码
    if command -v qrencode >/dev/null 2>&1; then
        echo ""
        log_info "客户端 $client_name 的二维码："
        qrencode -t ansiutf8 < "$client_dir/$client_name.conf"
        echo ""
    fi

    echo "客户端配置文件位置: $client_dir/$client_name.conf"
    echo ""
    echo "配置内容："
    cat "$client_dir/$client_name.conf"
}

# 生成Windows客户端配置
generate_windows_client_config() {
    local client_name=$1
    local client_ip=$2
    local traffic_mode=$3  # full 或 partial

    log_info "为Windows客户端 $client_name 生成优化配置..."

    # 生成客户端密钥对
    local client_private_key=$(wg genkey)
    local client_public_key=$(echo "$client_private_key" | wg pubkey)

    # 创建客户端配置目录
    local client_dir="$WG_CONFIG_DIR/clients"
    mkdir -p "$client_dir"

    # 根据流量模式设置AllowedIPs和DNS
    local allowed_ips=""
    local dns_servers=""
    local config_suffix=""

    if [[ $traffic_mode == "partial" ]]; then
        # 内网访问模式
        allowed_ips="10.66.0.0/16, 192.168.0.0/16, 172.16.0.0/12"
        dns_servers="223.5.5.5, 119.29.29.29"
        config_suffix="-internal"
        log_info "配置模式: 内网访问（仅访问服务端内网资源）"
    else
        # 全局代理模式
        allowed_ips="0.0.0.0/0"
        dns_servers="223.5.5.5, 119.29.29.29, 8.8.8.8"
        config_suffix="-global"
        log_info "配置模式: 全局代理（所有流量通过VPN）"
    fi

    # 生成Windows优化的客户端配置文件
    cat > "$client_dir/$client_name$config_suffix.conf" << EOF
[Interface]
PrivateKey = $client_private_key
Address = $client_ip/$(echo $PRIVATE_SUBNET | cut -d'/' -f2)
DNS = $dns_servers
# Windows客户端MTU优化
MTU = 1420

[Peer]
PublicKey = $SERVER_PUBLIC_KEY
Endpoint = $SERVER_IP:$WG_PORT
AllowedIPs = $allowed_ips
# Windows客户端保持连接优化
PersistentKeepalive = 25
EOF

    # 添加客户端到服务端配置
    cat >> "$WG_CONFIG_DIR/$WG_INTERFACE.conf" << EOF
# Windows Client: $client_name ($traffic_mode mode)
[Peer]
PublicKey = $client_public_key
AllowedIPs = $client_ip/32

EOF

    # 重启WireGuard服务
    systemctl restart wg-quick@$WG_INTERFACE >/dev/null 2>&1 || log_warn "服务重启失败"

    log_success "Windows客户端 $client_name 配置生成完成"

    # 显示Windows客户端特殊说明
    echo ""
    echo -e "${CYAN}=== Windows客户端使用说明 ===${NC}"
    echo "1. 📱 推荐使用官方WireGuard客户端"
    echo "2. 🔧 以管理员身份运行客户端"
    echo "3. 🛡️ 在Windows防火墙中允许WireGuard"
    echo "4. ⚡ MTU已优化为1420，适合大多数网络环境"

    if [[ $traffic_mode == "partial" ]]; then
        echo "5. 🌐 当前为内网访问模式，本地网络不受影响"
        echo "6. 🔗 可访问服务端内网资源：10.66.0.0/16, 192.168.0.0/16, 172.16.0.0/12"
    else
        echo "5. 🌍 当前为全局代理模式，所有流量通过VPN"
        echo "6. 🔒 提供完整的网络隐私保护"
    fi
    echo ""

    # 生成二维码
    if command -v qrencode >/dev/null 2>&1; then
        echo ""
        log_info "Windows客户端 $client_name 的二维码："
        qrencode -t ansiutf8 < "$client_dir/$client_name$config_suffix.conf"
        echo ""
    fi

    echo "Windows客户端配置文件位置: $client_dir/$client_name$config_suffix.conf"
    echo ""
    echo "配置内容："
    cat "$client_dir/$client_name$config_suffix.conf"
}

# 添加客户端
add_client() {
    log_info "添加新客户端..."

    # 获取客户端名称
    local client_name=""
    while true; do
        read -p "请输入客户端名称: " client_name
        if [[ -z $client_name ]]; then
            log_error "客户端名称不能为空"
            continue
        fi

        # 检查是否已存在（包括Windows客户端的不同配置文件）
        if [[ -f "$WG_CONFIG_DIR/clients/$client_name.conf" ]] || \
           [[ -f "$WG_CONFIG_DIR/clients/$client_name-global.conf" ]] || \
           [[ -f "$WG_CONFIG_DIR/clients/$client_name-internal.conf" ]]; then
            log_error "客户端 $client_name 已存在"
            continue
        fi

        break
    done

    # 询问客户端类型
    echo ""
    echo -e "${CYAN}请选择客户端类型：${NC}"
    echo "1. Windows客户端（推荐，包含优化配置）"
    echo "2. 其他客户端（Linux/macOS/Android/iOS等）"
    echo ""

    local client_type=""
    while true; do
        read -p "请选择客户端类型 (1-2): " client_type
        case $client_type in
            1)
                client_type="windows"
                break
                ;;
            2)
                client_type="other"
                break
                ;;
            *)
                log_error "请输入有效的选项 (1-2)"
                ;;
        esac
    done

    # 如果是Windows客户端，询问流量模式
    local traffic_mode=""
    if [[ $client_type == "windows" ]]; then
        echo ""
        echo -e "${CYAN}请选择Windows客户端流量模式：${NC}"
        echo ""
        echo -e "${GREEN}1. 全局代理模式${NC}"
        echo "   • 所有网络流量都通过VPN"
        echo "   • 完全的IP地址隐藏和隐私保护"
        echo "   • 适合：网络隐私保护、绕过地理限制"
        echo ""
        echo -e "${BLUE}2. 内网访问模式${NC}"
        echo "   • 仅内网流量通过VPN"
        echo "   • 本地网络访问不受影响"
        echo "   • 适合：远程办公、访问公司内网资源"
        echo ""

        while true; do
            read -p "请选择流量模式 (1-2): " mode_choice
            case $mode_choice in
                1)
                    traffic_mode="full"
                    log_info "已选择：全局代理模式"
                    break
                    ;;
                2)
                    traffic_mode="partial"
                    log_info "已选择：内网访问模式"
                    break
                    ;;
                *)
                    log_error "请输入有效的选项 (1-2)"
                    ;;
            esac
        done
    fi

    # 获取下一个可用IP
    local subnet_base=$(echo "$PRIVATE_SUBNET" | cut -d'/' -f1 | cut -d'.' -f1-3)
    local next_ip=""

    for i in {2..254}; do
        local test_ip="$subnet_base.$i"
        if ! grep -q "$test_ip" "$WG_CONFIG_DIR/$WG_INTERFACE.conf" 2>/dev/null; then
            next_ip="$test_ip"
            break
        fi
    done

    if [[ -z $next_ip ]]; then
        log_error "没有可用的IP地址"
        return 1
    fi

    # 根据客户端类型生成配置
    if [[ $client_type == "windows" ]]; then
        generate_windows_client_config "$client_name" "$next_ip" "$traffic_mode"
    else
        generate_client_config "$client_name" "$next_ip"
    fi

    ((CLIENT_COUNT++))

    echo ""
    log_success "客户端添加完成！"

    # 显示后续操作建议
    if [[ $client_type == "windows" ]]; then
        echo ""
        echo -e "${YELLOW}Windows客户端后续操作：${NC}"
        echo "1. 下载WireGuard客户端：https://www.wireguard.com/install/"
        echo "2. 以管理员身份运行WireGuard客户端"
        echo "3. 导入上面显示的配置文件或扫描二维码"
        echo "4. 在Windows防火墙中允许WireGuard应用"
        echo "5. 连接并测试网络连通性"
    else
        echo ""
        echo -e "${YELLOW}客户端后续操作：${NC}"
        echo "1. 将配置文件传输到客户端设备"
        echo "2. 导入配置文件到WireGuard客户端"
        echo "3. 连接并测试网络连通性"
    fi
}

# 列出所有客户端
list_clients() {
    log_info "客户端列表："

    local client_dir="$WG_CONFIG_DIR/clients"
    if [[ ! -d $client_dir ]] || [[ -z $(ls -A "$client_dir" 2>/dev/null) ]]; then
        echo "暂无客户端"
        return
    fi

    echo ""
    printf "%-25s %-15s %-12s %-10s\n" "客户端名称" "IP地址" "类型" "状态"
    echo "================================================================"

    # 用于跟踪已处理的客户端名称（避免Windows客户端重复显示）
    local processed_clients=()

    for config_file in "$client_dir"/*.conf; do
        if [[ -f $config_file ]]; then
            local full_name=$(basename "$config_file" .conf)
            local client_ip=$(grep "Address" "$config_file" | cut -d'=' -f2 | cut -d'/' -f1 | tr -d ' ')
            local status="离线"
            local client_type="普通"
            local display_name="$full_name"

            # 检查是否是Windows客户端
            if [[ $full_name =~ -global$ ]]; then
                client_type="Windows(全局)"
                display_name="${full_name%-global}"
            elif [[ $full_name =~ -internal$ ]]; then
                client_type="Windows(内网)"
                display_name="${full_name%-internal}"
            fi

            # 检查是否已经处理过这个客户端（避免Windows客户端重复）
            local already_processed=false
            for processed in "${processed_clients[@]}"; do
                if [[ $processed == $display_name ]]; then
                    already_processed=true
                    break
                fi
            done

            if [[ $already_processed == true ]]; then
                continue
            fi

            # 检查客户端是否在线（通过WireGuard状态）
            if command -v wg >/dev/null 2>&1 && wg show | grep -q "$client_ip"; then
                status="在线"
            fi

            printf "%-25s %-15s %-12s %-10s\n" "$display_name" "$client_ip" "$client_type" "$status"
            processed_clients+=("$display_name")
        fi
    done

    echo ""

    # 显示统计信息
    local total_clients=${#processed_clients[@]}
    local online_clients=0
    if command -v wg >/dev/null 2>&1; then
        online_clients=$(wg show | grep -c "peer:" 2>/dev/null || echo "0")
    fi

    echo "总客户端数: $total_clients | 在线: $online_clients | 离线: $((total_clients - online_clients))"
    echo ""

    # 显示Windows客户端特别说明
    local has_windows_clients=false
    for config_file in "$client_dir"/*.conf; do
        if [[ -f $config_file ]] && [[ $(basename "$config_file") =~ -(global|internal)\.conf$ ]]; then
            has_windows_clients=true
            break
        fi
    done

    if [[ $has_windows_clients == true ]]; then
        echo -e "${CYAN}Windows客户端说明：${NC}"
        echo "• 全局模式：所有流量通过VPN"
        echo "• 内网模式：仅访问服务端内网资源"
        echo ""
    fi
}

# 显示服务状态
show_status() {
    log_info "WireGuard服务状态："
    echo ""

    # 服务状态
    if systemctl is-active --quiet wg-quick@$WG_INTERFACE; then
        echo -e "${GREEN}服务状态: 运行中${NC}"
    else
        echo -e "${RED}服务状态: 已停止${NC}"
    fi

    # 接口状态
    if ip link show "$WG_INTERFACE" >/dev/null 2>&1; then
        echo -e "${GREEN}接口状态: 已启用${NC}"
        echo "接口信息:"
        ip addr show "$WG_INTERFACE" | grep -E "(inet|mtu)"
    else
        echo -e "${RED}接口状态: 未启用${NC}"
    fi

    echo ""

    # WireGuard详细状态
    if command -v wg >/dev/null 2>&1; then
        echo "WireGuard连接状态:"
        wg show
    fi

    echo ""

    # 客户端统计
    local client_dir="$WG_CONFIG_DIR/clients"
    if [[ -d $client_dir ]]; then
        local client_count=$(ls -1 "$client_dir"/*.conf 2>/dev/null | wc -l)
        echo "客户端数量: $client_count"
    fi
}

# 网络诊断
network_diagnosis() {
    log_info "网络诊断..."
    echo ""

    # 检查WireGuard服务
    echo "=== WireGuard服务检查 ==="
    if systemctl is-active --quiet wg-quick@$WG_INTERFACE; then
        echo -e "${GREEN}✓ WireGuard服务运行正常${NC}"
    else
        echo -e "${RED}✗ WireGuard服务未运行${NC}"
    fi

    # 检查网络接口
    echo ""
    echo "=== 网络接口检查 ==="
    if ip link show "$WG_INTERFACE" >/dev/null 2>&1; then
        echo -e "${GREEN}✓ WireGuard接口存在${NC}"
        ip addr show "$WG_INTERFACE"
    else
        echo -e "${RED}✗ WireGuard接口不存在${NC}"
    fi

    # 检查防火墙
    echo ""
    echo "=== 防火墙检查 ==="
    if iptables -L INPUT | grep -q "$WG_PORT"; then
        echo -e "${GREEN}✓ 防火墙规则正常${NC}"
    else
        echo -e "${YELLOW}! 防火墙规则可能有问题${NC}"
    fi

    # 检查端口监听
    echo ""
    echo "=== 端口监听检查 ==="
    if command -v ss >/dev/null 2>&1 && ss -ulpn | grep -q ":$WG_PORT"; then
        echo -e "${GREEN}✓ WireGuard端口监听正常${NC}"
    else
        echo -e "${RED}✗ WireGuard端口未监听${NC}"
    fi

    # 检查IP转发
    echo ""
    echo "=== IP转发检查 ==="
    if [[ $(cat /proc/sys/net/ipv4/ip_forward) == "1" ]]; then
        echo -e "${GREEN}✓ IP转发已启用${NC}"
    else
        echo -e "${RED}✗ IP转发未启用${NC}"
    fi

    # 网络连通性测试
    echo ""
    echo "=== 网络连通性测试 ==="
    local test_hosts=("8.8.8.8" "1.1.1.1")
    for host in "${test_hosts[@]}"; do
        if ping -c 1 -W 3 "$host" >/dev/null 2>&1; then
            echo -e "${GREEN}✓ $host 连通正常${NC}"
        else
            echo -e "${RED}✗ $host 连通失败${NC}"
        fi
    done

    echo ""
}

# 显示主菜单
show_main_menu() {
    clear
    show_banner

    echo -e "${WHITE}请选择操作：${NC}"
    echo ""
    echo "1. 安装WireGuard服务端"
    echo "2. 添加客户端"
    echo "3. 删除客户端"
    echo "4. 列出所有客户端"
    echo "5. 显示服务状态"
    echo "6. 网络诊断"
    echo "7. 卸载WireGuard"
    echo "0. 退出"
    echo ""
}

# 安装服务端
install_server() {
    log_info "开始安装WireGuard服务端..."

    # 检查是否已安装
    if [[ -f "$WG_CONFIG_DIR/$WG_INTERFACE.conf" ]]; then
        log_warn "WireGuard服务端已安装"
        read -p "是否重新安装？(y/N): " confirm
        if [[ ! $confirm =~ ^[Yy]$ ]]; then
            return
        fi
    fi

    echo ""
    log_info "开始系统检测和配置..."

    # 系统检测
    detect_system
    detect_network_environment
    test_network_connectivity
    get_server_ip

    # 配置选择
    select_wireguard_port
    select_private_subnet

    echo ""
    log_info "开始安装和配置WireGuard..."

    # 安装和配置
    install_dependencies
    generate_keys
    configure_system_optimization
    configure_firewall
    create_server_config
    start_wireguard_service

    echo ""
    log_success "WireGuard服务端安装完成！"
    echo ""
    echo -e "${GREEN}服务器信息：${NC}"
    echo "公网IP: $SERVER_IP"
    echo "端口: $WG_PORT"
    echo "私网段: $PRIVATE_SUBNET"
    echo "服务器内网IP: $PRIVATE_SUBNET_IP"
    echo ""
    echo "现在可以添加客户端了！"
    echo ""

    read -p "按回车键继续..."
}

# 删除客户端
remove_client() {
    log_info "删除客户端..."

    local client_dir="$WG_CONFIG_DIR/clients"
    if [[ ! -d $client_dir ]] || [[ -z $(ls -A "$client_dir" 2>/dev/null) ]]; then
        log_warn "暂无客户端可删除"
        return
    fi

    echo "现有客户端："
    local clients=()
    local i=1
    for config_file in "$client_dir"/*.conf; do
        if [[ -f $config_file ]]; then
            local client_name=$(basename "$config_file" .conf)
            clients+=("$client_name")
            echo "$i. $client_name"
            ((i++))
        fi
    done

    read -p "请选择要删除的客户端编号: " choice
    if [[ ! $choice =~ ^[0-9]+$ ]] || [[ $choice -lt 1 ]] || [[ $choice -gt ${#clients[@]} ]]; then
        log_error "无效的选择"
        return
    fi

    local client_name="${clients[$((choice-1))]}"

    # 确认删除
    read -p "确认删除客户端 $client_name？(y/N): " confirm
    if [[ ! $confirm =~ ^[Yy]$ ]]; then
        log_info "取消删除"
        return
    fi

    # 获取客户端公钥并从服务端配置中删除
    local client_config="$client_dir/$client_name.conf"
    if [[ -f $client_config ]]; then
        # 简单的删除方法：重新生成服务端配置
        local temp_config=$(mktemp)
        grep -v "# Client: $client_name" "$WG_CONFIG_DIR/$WG_INTERFACE.conf" > "$temp_config" || true
        mv "$temp_config" "$WG_CONFIG_DIR/$WG_INTERFACE.conf"

        # 删除客户端配置文件
        rm -f "$client_config"

        # 重启WireGuard服务
        systemctl restart wg-quick@$WG_INTERFACE >/dev/null 2>&1 || log_warn "服务重启失败"

        log_info "客户端 $client_name 删除完成"
    else
        log_error "客户端配置文件不存在"
    fi
}

# 卸载WireGuard
uninstall_wireguard() {
    log_warn "卸载WireGuard..."

    read -p "确认卸载WireGuard？这将删除所有配置 (y/N): " confirm
    if [[ ! $confirm =~ ^[Yy]$ ]]; then
        log_info "取消卸载"
        return
    fi

    # 停止并禁用服务
    systemctl stop wg-quick@$WG_INTERFACE 2>/dev/null || true
    systemctl disable wg-quick@$WG_INTERFACE 2>/dev/null || true

    # 删除网络接口
    ip link delete "$WG_INTERFACE" 2>/dev/null || true

    # 备份并删除配置
    if [[ -d $WG_CONFIG_DIR ]]; then
        local backup_file="/root/wireguard-backup-$(date +%Y%m%d-%H%M%S).tar.gz"
        tar -czf "$backup_file" -C / etc/wireguard 2>/dev/null || true
        log_info "配置已备份到: $backup_file"
        rm -rf "$WG_CONFIG_DIR"
    fi

    # 清理防火墙规则
    iptables -D INPUT -p udp --dport "$WG_PORT" -j ACCEPT 2>/dev/null || true
    iptables -D FORWARD -i "$WG_INTERFACE" -j ACCEPT 2>/dev/null || true
    iptables -D FORWARD -o "$WG_INTERFACE" -j ACCEPT 2>/dev/null || true
    iptables -t nat -D POSTROUTING -o eth0 -j MASQUERADE 2>/dev/null || true

    log_info "WireGuard卸载完成"
}

# 主程序
main() {
    # 检查root权限
    check_root

    while true; do
        show_main_menu
        read -p "请输入选项 (0-7): " choice

        case $choice in
            1)
                install_server
                ;;
            2)
                if [[ ! -f "$WG_CONFIG_DIR/$WG_INTERFACE.conf" ]]; then
                    log_error "请先安装WireGuard服务端"
                    read -p "按回车键继续..."
                    continue
                fi
                add_client
                read -p "按回车键继续..."
                ;;
            3)
                if [[ ! -f "$WG_CONFIG_DIR/$WG_INTERFACE.conf" ]]; then
                    log_error "请先安装WireGuard服务端"
                    read -p "按回车键继续..."
                    continue
                fi
                remove_client
                read -p "按回车键继续..."
                ;;
            4)
                if [[ ! -f "$WG_CONFIG_DIR/$WG_INTERFACE.conf" ]]; then
                    log_error "请先安装WireGuard服务端"
                    read -p "按回车键继续..."
                    continue
                fi
                list_clients
                read -p "按回车键继续..."
                ;;
            5)
                show_status
                read -p "按回车键继续..."
                ;;
            6)
                network_diagnosis
                read -p "按回车键继续..."
                ;;
            7)
                uninstall_wireguard
                read -p "按回车键继续..."
                ;;
            0)
                log_info "感谢使用WireGuard一体化安装脚本！"
                echo ""
                echo "项目地址: https://github.com/senma231/WG-install"
                echo "如有问题请提交Issue反馈"
                exit 0
                ;;
            *)
                log_error "无效的选项，请重新选择"
                read -p "按回车键继续..."
                ;;
        esac
    done
}

# 显示帮助信息
show_help() {
    echo "WireGuard 一体化安装脚本 v$SCRIPT_VERSION"
    echo ""
    echo "用法: $0 [选项]"
    echo ""
    echo "选项:"
    echo "  -h, --help     显示此帮助信息"
    echo "  -v, --version  显示版本信息"
    echo "  -d, --debug    启用调试模式"
    echo ""
    echo "功能特性:"
    echo "  • 完全交互式安装界面"
    echo "  • 国内外网络环境自动适配"
    echo "  • 智能网络优化配置"
    echo "  • 批量客户端管理"
    echo "  • 系统监控和故障诊断"
    echo "  • 单文件集成，无需额外依赖"
    echo ""
    echo "快速开始:"
    echo "  sudo $0"
    echo ""
}

# 处理命令行参数
case "${1:-}" in
    -h|--help)
        show_help
        exit 0
        ;;
    -v|--version)
        echo "WireGuard一体化安装脚本 v$SCRIPT_VERSION"
        exit 0
        ;;
    -d|--debug)
        DEBUG_MODE=true
        echo "调试模式已启用"
        ;;
    "")
        # 正常运行
        ;;
    *)
        echo "未知选项: $1"
        echo "使用 $0 --help 查看帮助"
        exit 1
        ;;
esac

# 脚本入口
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi

# 安装系统依赖
install_dependencies() {
    log_info "安装系统依赖..."

    case $SYSTEM_TYPE in
        ubuntu|debian)
            # 配置国内镜像源
            if [[ $IS_CHINA_NETWORK == true ]]; then
                log_info "配置国内镜像源..."
                cp /etc/apt/sources.list /etc/apt/sources.list.backup 2>/dev/null || true

                if [[ $SYSTEM_TYPE == "ubuntu" ]]; then
                    cat > /etc/apt/sources.list << EOF
deb https://mirrors.aliyun.com/ubuntu/ $(lsb_release -cs) main restricted universe multiverse
deb https://mirrors.aliyun.com/ubuntu/ $(lsb_release -cs)-updates main restricted universe multiverse
deb https://mirrors.aliyun.com/ubuntu/ $(lsb_release -cs)-backports main restricted universe multiverse
deb https://mirrors.aliyun.com/ubuntu/ $(lsb_release -cs)-security main restricted universe multiverse
EOF
                else
                    cat > /etc/apt/sources.list << EOF
deb https://mirrors.aliyun.com/debian/ $(lsb_release -cs) main non-free contrib
deb https://mirrors.aliyun.com/debian/ $(lsb_release -cs)-updates main non-free contrib
deb https://mirrors.aliyun.com/debian/ $(lsb_release -cs)-backports main non-free contrib
deb https://mirrors.aliyun.com/debian-security/ $(lsb_release -cs)-security main non-free contrib
EOF
                fi
            fi

            apt update
            apt install -y wireguard wireguard-tools iptables qrencode curl wget net-tools || {
                log_warn "部分软件包安装失败，尝试基础安装..."
                apt install -y wireguard wireguard-tools iptables curl wget
            }
            ;;

        centos|rhel|fedora)
            if [[ $IS_CHINA_NETWORK == true ]]; then
                log_info "配置国内镜像源..."
                if [[ $SYSTEM_TYPE == "centos" ]]; then
                    sed -e 's|^mirrorlist=|#mirrorlist=|g' \
                        -e 's|^#baseurl=http://mirror.centos.org|baseurl=https://mirrors.aliyun.com|g' \
                        -i.bak /etc/yum.repos.d/CentOS-*.repo 2>/dev/null || true
                fi
            fi

            if command -v dnf >/dev/null 2>&1; then
                dnf install -y epel-release || true
                dnf install -y wireguard-tools iptables qrencode curl wget net-tools || {
                    log_warn "部分软件包安装失败，尝试基础安装..."
                    dnf install -y wireguard-tools iptables curl wget
                }
            else
                yum install -y epel-release || true
                yum install -y wireguard-tools iptables qrencode curl wget net-tools || {
                    log_warn "部分软件包安装失败，尝试基础安装..."
                    yum install -y wireguard-tools iptables curl wget
                }
            fi
            ;;

        *)
            log_error "不支持的系统类型: $SYSTEM_TYPE"
            exit 1
            ;;
    esac

    log_info "依赖安装完成"
}

# 生成密钥对
generate_keys() {
    log_info "生成WireGuard密钥对..."

    # 创建配置目录
    mkdir -p "$WG_CONFIG_DIR"
    chmod 700 "$WG_CONFIG_DIR"

    # 生成服务端密钥
    SERVER_PRIVATE_KEY=$(wg genkey)
    SERVER_PUBLIC_KEY=$(echo "$SERVER_PRIVATE_KEY" | wg pubkey)

    log_info "密钥生成完成"
    log_debug "服务端公钥: $SERVER_PUBLIC_KEY"
}

# 系统优化配置
configure_system_optimization() {
    log_info "配置系统网络优化..."

    # 备份原始配置
    cp /etc/sysctl.conf /etc/sysctl.conf.backup 2>/dev/null || true

    # 启用IP转发
    if ! grep -q "net.ipv4.ip_forward = 1" /etc/sysctl.conf; then
        echo 'net.ipv4.ip_forward = 1' >> /etc/sysctl.conf
    fi
    if ! grep -q "net.ipv6.conf.all.forwarding = 1" /etc/sysctl.conf; then
        echo 'net.ipv6.conf.all.forwarding = 1' >> /etc/sysctl.conf
    fi

    # 针对国内网络的优化
    if [[ $IS_CHINA_NETWORK == true ]]; then
        log_info "应用国内网络优化配置..."

        cat >> /etc/sysctl.conf << 'EOF'

# WireGuard 国内网络优化
net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbr
net.ipv4.tcp_fastopen = 3
net.ipv4.tcp_mtu_probing = 1
net.core.rmem_max = 134217728
net.core.wmem_max = 134217728
net.ipv4.tcp_rmem = 4096 87380 134217728
net.ipv4.tcp_wmem = 4096 65536 134217728
net.ipv4.udp_rmem_min = 8192
net.ipv4.udp_wmem_min = 8192
net.core.netdev_max_backlog = 5000
EOF
    fi

    # 应用系统参数
    sysctl -p >/dev/null 2>&1 || log_warn "部分系统参数应用失败"

    log_info "系统优化配置完成"
}

# 配置防火墙
configure_firewall() {
    log_info "配置防火墙规则..."

    # 检测防火墙类型并配置
    if command -v ufw >/dev/null 2>&1 && ufw status | grep -q "Status: active"; then
        log_info "配置UFW防火墙..."
        ufw allow "$WG_PORT"/udp >/dev/null 2>&1 || log_warn "UFW规则添加失败"
        ufw allow ssh >/dev/null 2>&1 || true
    elif command -v firewall-cmd >/dev/null 2>&1 && systemctl is-active --quiet firewalld; then
        log_info "配置firewalld防火墙..."
        firewall-cmd --permanent --add-port="$WG_PORT"/udp >/dev/null 2>&1 || log_warn "firewalld规则添加失败"
        firewall-cmd --permanent --add-masquerade >/dev/null 2>&1 || true
        firewall-cmd --reload >/dev/null 2>&1 || true
    else
        log_info "配置iptables防火墙..."
        # 添加iptables规则
        iptables -A INPUT -p udp --dport "$WG_PORT" -j ACCEPT 2>/dev/null || log_warn "iptables INPUT规则添加失败"
        iptables -A FORWARD -i "$WG_INTERFACE" -j ACCEPT 2>/dev/null || true
        iptables -A FORWARD -o "$WG_INTERFACE" -j ACCEPT 2>/dev/null || true
        iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE 2>/dev/null || true

        # 尝试保存iptables规则
        if command -v iptables-save >/dev/null 2>&1; then
            iptables-save > /etc/iptables/rules.v4 2>/dev/null || true
        fi
    fi

    log_info "防火墙配置完成"
}
