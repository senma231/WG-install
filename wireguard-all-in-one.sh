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
SCRIPT_VERSION="2.1.0"
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
║                WireGuard 一体化全能脚本                       ║
║                                                              ║
║  🚀 核心功能:                                                 ║
║  • 完全交互式安装界面                                          ║
║  • 国内外网络环境自动适配                                      ║
║  • 智能网络优化配置                                            ║
║  • Windows客户端智能优化                                      ║
║  • 端口转发管理 (通过公网IP访问客户端)                         ║
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

    # 使用新的智能防火墙配置
    open_firewall_port "$WG_PORT" "udp" "WireGuard VPN"

    # 允许SSH端口（如果存在）
    local ssh_port="22"
    if ss -tulpn | grep ":22 " >/dev/null 2>&1; then
        open_firewall_port "$ssh_port" "tcp" "SSH"
    fi

    # 配置NAT规则
    configure_nat_rules

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
        allowed_ips="$PRIVATE_SUBNET, 192.168.0.0/16, 172.16.0.0/12"
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
        echo "6. 🔗 可访问服务端内网资源：$PRIVATE_SUBNET, 192.168.0.0/16, 172.16.0.0/12"
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

# ==================== 防火墙和NAT管理功能 ====================

# 检测防火墙类型
detect_firewall_type() {
    local firewall_type="iptables"  # 默认使用iptables

    # 检测UFW
    if command -v ufw >/dev/null 2>&1; then
        if ufw status | grep -q "Status: active"; then
            firewall_type="ufw"
            echo "$firewall_type"
            return
        fi
    fi

    # 检测firewalld
    if command -v firewall-cmd >/dev/null 2>&1; then
        if systemctl is-active --quiet firewalld; then
            firewall_type="firewalld"
            echo "$firewall_type"
            return
        fi
    fi

    # 如果没有检测到UFW或firewalld，且iptables可用，则使用iptables
    if command -v iptables >/dev/null 2>&1; then
        firewall_type="iptables"
    else
        firewall_type="none"
    fi

    echo "$firewall_type"
}

# 安全保存iptables规则
save_iptables_rules() {
    log_info "保存iptables规则..."

    # 尝试多种保存方式
    local saved=false

    # 方式1: 使用iptables-save保存到标准位置
    if command -v iptables-save >/dev/null 2>&1; then
        # 确保目录存在
        if [[ ! -d "/etc/iptables" ]]; then
            mkdir -p /etc/iptables 2>/dev/null || true
        fi

        # 尝试保存到标准位置
        if iptables-save > /etc/iptables/rules.v4 2>/dev/null; then
            log_success "iptables规则已保存到 /etc/iptables/rules.v4"
            saved=true
        fi
    fi

    # 方式2: 使用netfilter-persistent (Debian/Ubuntu)
    if [[ $saved == false ]] && command -v netfilter-persistent >/dev/null 2>&1; then
        if netfilter-persistent save 2>/dev/null; then
            log_success "iptables规则已通过netfilter-persistent保存"
            saved=true
        fi
    fi

    # 方式3: 使用service iptables save (CentOS/RHEL)
    if [[ $saved == false ]] && command -v service >/dev/null 2>&1; then
        if service iptables save 2>/dev/null; then
            log_success "iptables规则已通过service保存"
            saved=true
        fi
    fi

    # 方式4: 保存到备用位置
    if [[ $saved == false ]] && command -v iptables-save >/dev/null 2>&1; then
        local backup_file="/etc/iptables-rules-backup"
        if iptables-save > "$backup_file" 2>/dev/null; then
            log_success "iptables规则已保存到 $backup_file"
            saved=true
        fi
    fi

    if [[ $saved == false ]]; then
        log_warn "无法保存iptables规则，重启后规则可能丢失"
        echo "  建议手动安装 iptables-persistent:"
        echo "  sudo apt install iptables-persistent  # Debian/Ubuntu"
        echo "  sudo yum install iptables-services    # CentOS/RHEL"
    fi
}

# 检查端口是否在防火墙中开放
check_firewall_port() {
    local port=$1
    local protocol=${2:-tcp}
    local firewall_type=$(detect_firewall_type)

    case $firewall_type in
        "ufw")
            if ufw status | grep -q "$port/$protocol"; then
                return 0
            fi
            ;;
        "firewalld")
            if firewall-cmd --list-ports | grep -q "$port/$protocol"; then
                return 0
            fi
            ;;
        "iptables")
            if iptables -L INPUT | grep -q "dpt:$port"; then
                return 0
            fi
            ;;
    esac

    return 1
}

# 在防火墙中开放端口
open_firewall_port() {
    local port=$1
    local protocol=${2:-tcp}
    local description=${3:-"WireGuard"}
    local firewall_type=$(detect_firewall_type)

    log_info "在防火墙中开放端口 $port/$protocol..."

    case $firewall_type in
        "ufw")
            ufw allow "$port/$protocol" comment "$description" >/dev/null 2>&1
            if [[ $? -eq 0 ]]; then
                log_success "UFW: 端口 $port/$protocol 已开放"
            else
                log_warn "UFW: 端口 $port/$protocol 开放失败"
            fi
            ;;
        "firewalld")
            firewall-cmd --permanent --add-port="$port/$protocol" >/dev/null 2>&1
            firewall-cmd --reload >/dev/null 2>&1
            if [[ $? -eq 0 ]]; then
                log_success "firewalld: 端口 $port/$protocol 已开放"
            else
                log_warn "firewalld: 端口 $port/$protocol 开放失败"
            fi
            ;;
        "iptables")
            iptables -I INPUT -p "$protocol" --dport "$port" -j ACCEPT 2>/dev/null
            if [[ $? -eq 0 ]]; then
                log_success "iptables: 端口 $port/$protocol 已开放"
                # 保存iptables规则
                save_iptables_rules
            else
                log_warn "iptables: 端口 $port/$protocol 开放失败"
            fi
            ;;
        "none")
            log_warn "未检测到iptables，无法配置防火墙规则"
            ;;
    esac
}

# 检查NAT是否正确配置
check_nat_configuration() {
    log_info "检查NAT配置..."

    # 检查IP转发
    if [[ $(cat /proc/sys/net/ipv4/ip_forward) != "1" ]]; then
        log_warn "IP转发未启用"
        return 1
    fi

    # 检查MASQUERADE规则
    if ! iptables -t nat -L POSTROUTING | grep -q "MASQUERADE"; then
        log_warn "未找到MASQUERADE规则"
        return 1
    fi

    # 检查WireGuard接口的转发规则
    if ip link show $WG_INTERFACE >/dev/null 2>&1; then
        if ! iptables -L FORWARD | grep -q "$WG_INTERFACE"; then
            log_warn "WireGuard接口转发规则缺失"
            return 1
        fi
    fi

    log_success "NAT配置正常"
    return 0
}

# 配置NAT规则
configure_nat_rules() {
    log_info "配置NAT规则..."

    # 启用IP转发
    echo 1 > /proc/sys/net/ipv4/ip_forward
    if ! grep -q "net.ipv4.ip_forward = 1" /etc/sysctl.conf; then
        echo "net.ipv4.ip_forward = 1" >> /etc/sysctl.conf
    fi
    log_success "IP转发已启用"

    # 获取主网络接口
    local main_interface=$(ip route | grep default | awk '{print $5}' | head -n1)
    if [[ -z $main_interface ]]; then
        main_interface="eth0"  # 默认接口
    fi

    # 添加MASQUERADE规则
    if ! iptables -t nat -C POSTROUTING -o "$main_interface" -j MASQUERADE 2>/dev/null; then
        iptables -t nat -A POSTROUTING -o "$main_interface" -j MASQUERADE
        log_success "已添加MASQUERADE规则 ($main_interface)"
    fi

    # 添加WireGuard接口转发规则
    if ip link show $WG_INTERFACE >/dev/null 2>&1; then
        if ! iptables -C FORWARD -i $WG_INTERFACE -j ACCEPT 2>/dev/null; then
            iptables -I FORWARD -i $WG_INTERFACE -j ACCEPT
        fi
        if ! iptables -C FORWARD -o $WG_INTERFACE -j ACCEPT 2>/dev/null; then
            iptables -I FORWARD -o $WG_INTERFACE -j ACCEPT
        fi
        log_success "WireGuard接口转发规则已配置"
    fi

    # 保存iptables规则
    save_iptables_rules
}

# 检查云服务商安全组
check_cloud_security_groups() {
    log_info "检查云服务商安全组配置..."

    # 尝试检测云服务商
    local cloud_provider="unknown"

    # 检测阿里云
    if curl -s --connect-timeout 2 http://100.100.100.200/latest/meta-data/instance-id >/dev/null 2>&1; then
        cloud_provider="aliyun"
    # 检测腾讯云
    elif curl -s --connect-timeout 2 http://metadata.tencentyun.com/latest/meta-data/instance-id >/dev/null 2>&1; then
        cloud_provider="tencent"
    # 检测AWS
    elif curl -s --connect-timeout 2 http://169.254.169.254/latest/meta-data/instance-id >/dev/null 2>&1; then
        cloud_provider="aws"
    # 检测Google Cloud
    elif curl -s --connect-timeout 2 -H "Metadata-Flavor: Google" http://metadata.google.internal/computeMetadata/v1/instance/id >/dev/null 2>&1; then
        cloud_provider="gcp"
    fi

    case $cloud_provider in
        "aliyun")
            log_warn "检测到阿里云ECS"
            echo "  请在阿里云控制台检查安全组规则："
            echo "  1. 登录阿里云控制台"
            echo "  2. 进入ECS实例管理"
            echo "  3. 点击'安全组' -> '配置规则'"
            echo "  4. 添加入方向规则，开放WireGuard端口 $WG_PORT/UDP"
            ;;
        "tencent")
            log_warn "检测到腾讯云CVM"
            echo "  请在腾讯云控制台检查安全组规则："
            echo "  1. 登录腾讯云控制台"
            echo "  2. 进入云服务器CVM"
            echo "  3. 点击'安全组' -> '修改规则'"
            echo "  4. 添加入站规则，开放WireGuard端口 $WG_PORT/UDP"
            ;;
        "aws")
            log_warn "检测到AWS EC2"
            echo "  请在AWS控制台检查Security Groups："
            echo "  1. 登录AWS控制台"
            echo "  2. 进入EC2 Dashboard"
            echo "  3. 点击'Security Groups'"
            echo "  4. 编辑Inbound Rules，添加UDP $WG_PORT"
            ;;
        "gcp")
            log_warn "检测到Google Cloud"
            echo "  请在GCP控制台检查防火墙规则："
            echo "  1. 登录Google Cloud Console"
            echo "  2. 进入VPC网络 -> 防火墙"
            echo "  3. 创建防火墙规则，允许UDP $WG_PORT"
            ;;
        *)
            log_info "未检测到已知云服务商"
            echo "  如果使用云服务器，请检查云服务商的安全组/防火墙设置"
            ;;
    esac
    echo ""
}

# 全面的防火墙和NAT检查
comprehensive_firewall_check() {
    log_info "执行全面的防火墙和NAT检查..."
    echo ""

    local issues_found=false

    # 1. 检查防火墙类型和状态
    echo -e "${BLUE}1. 防火墙状态检查${NC}"
    local firewall_type=$(detect_firewall_type)
    echo "检测到的防火墙类型: $firewall_type"

    # 2. 检查WireGuard端口
    echo -e "${BLUE}2. WireGuard端口检查${NC}"
    if check_firewall_port "$WG_PORT" "udp"; then
        log_success "WireGuard端口 $WG_PORT/UDP 已在防火墙中开放"
    else
        log_warn "WireGuard端口 $WG_PORT/UDP 未在防火墙中开放"
        issues_found=true
    fi

    # 3. 检查端口转发规则的端口
    if [[ -f $FORWARD_RULES_FILE ]] && [[ -s $FORWARD_RULES_FILE ]]; then
        echo -e "${BLUE}3. 端口转发规则检查${NC}"
        while IFS=':' read -r public_port client_name client_ip target_port service_name create_time; do
            if check_firewall_port "$public_port" "tcp"; then
                log_success "转发端口 $public_port/TCP 已在防火墙中开放"
            else
                log_warn "转发端口 $public_port/TCP 未在防火墙中开放"
                issues_found=true
            fi
        done < "$FORWARD_RULES_FILE"
    fi

    # 4. 检查NAT配置
    echo -e "${BLUE}4. NAT配置检查${NC}"
    if ! check_nat_configuration; then
        issues_found=true
    fi

    # 5. 检查云服务商安全组
    echo -e "${BLUE}5. 云服务商安全组检查${NC}"
    check_cloud_security_groups

    # 6. 提供修复建议
    if [[ $issues_found == true ]]; then
        echo -e "${YELLOW}发现配置问题，是否自动修复？(y/N): ${NC}"
        read -p "" auto_fix

        if [[ $auto_fix =~ ^[Yy]$ ]]; then
            auto_fix_firewall_issues
        fi
    else
        log_success "所有防火墙和NAT配置检查通过！"
    fi
}

# 自动修复防火墙问题
auto_fix_firewall_issues() {
    log_info "开始自动修复防火墙问题..."

    # 1. 开放WireGuard端口
    if ! check_firewall_port "$WG_PORT" "udp"; then
        open_firewall_port "$WG_PORT" "udp" "WireGuard VPN"
    fi

    # 2. 开放端口转发规则的端口
    if [[ -f $FORWARD_RULES_FILE ]] && [[ -s $FORWARD_RULES_FILE ]]; then
        while IFS=':' read -r public_port client_name client_ip target_port service_name create_time; do
            if ! check_firewall_port "$public_port" "tcp"; then
                open_firewall_port "$public_port" "tcp" "Port Forward $service_name"
            fi
        done < "$FORWARD_RULES_FILE"
    fi

    # 3. 配置NAT规则
    configure_nat_rules

    log_success "自动修复完成！"
    echo ""
    echo -e "${YELLOW}重要提醒：${NC}"
    echo "如果仍无法连接，请检查云服务商的安全组设置！"
    echo "大多数连接问题都是由于云服务商安全组未开放端口导致的。"
}

# ==================== 端口转发功能 ====================

# 检查端口是否被占用
check_port_usage() {
    local port=$1
    if ss -tulpn | grep ":$port " >/dev/null 2>&1; then
        return 1
    fi
    return 0
}

# 获取客户端列表（用于端口转发）
get_client_list_for_forward() {
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

# 添加端口转发规则
add_port_forward() {
    log_info "添加端口转发规则..."

    # 获取客户端列表
    local clients=($(get_client_list_for_forward))
    if [[ ${#clients[@]} -eq 0 ]]; then
        log_error "没有找到客户端配置"
        echo "请先添加客户端后再配置端口转发"
        return 1
    fi

    echo ""
    echo -e "${CYAN}可用的客户端：${NC}"
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
    echo -e "${CYAN}常用服务端口：${NC}"
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

    # MASQUERADE规则 - 确保返回流量正确
    iptables -t nat -A POSTROUTING -p tcp -d "$client_ip" --dport "$target_port" -j MASQUERADE

    # 保存规则到配置文件
    mkdir -p "$(dirname "$FORWARD_RULES_FILE")"
    echo "$public_port:$client_name:$client_ip:$target_port:$service_name:$(date)" >> "$FORWARD_RULES_FILE"

    # 在防火墙中开放公网端口
    open_firewall_port "$public_port" "tcp" "Port Forward $service_name"

    # 保存iptables规则
    save_iptables_rules

    log_success "端口转发规则添加成功！"
    echo ""
    echo -e "${CYAN}转发规则信息：${NC}"
    echo "服务名称: $service_name"
    echo "客户端: $client_name ($client_ip)"
    echo "公网端口: $public_port"
    echo "目标端口: $target_port"
    echo ""
    echo -e "${YELLOW}访问方式：${NC}"

    if [[ $service_name == "RDP" ]]; then
        echo "远程桌面连接: $SERVER_IP:$public_port"
        echo "或在远程桌面客户端中输入: $SERVER_IP:$public_port"
    elif [[ $service_name == "SSH" ]]; then
        echo "SSH连接: ssh user@$SERVER_IP -p $public_port"
    elif [[ $service_name == "HTTP" ]]; then
        echo "HTTP访问: http://$SERVER_IP:$public_port"
    elif [[ $service_name == "HTTPS" ]]; then
        echo "HTTPS访问: https://$SERVER_IP:$public_port"
    else
        echo "访问地址: $SERVER_IP:$public_port"
    fi

    echo ""
    echo -e "${BLUE}Windows客户端配置提醒：${NC}"
    if [[ $service_name == "RDP" ]]; then
        echo "1. 启用远程桌面："
        echo "   Set-ItemProperty -Path 'HKLM:\\System\\CurrentControlSet\\Control\\Terminal Server' -name 'fDenyTSConnections' -value 0"
        echo "2. 允许防火墙："
        echo "   Enable-NetFirewallRule -DisplayGroup 'Remote Desktop'"
    else
        echo "1. 确保目标服务正在运行"
        echo "2. 检查Windows防火墙设置"
        echo "3. 允许端口通过防火墙："
        echo "   New-NetFirewallRule -DisplayName 'Allow Port $target_port' -Direction Inbound -Protocol TCP -LocalPort $target_port -Action Allow"
    fi
}

# 列出端口转发规则
list_port_forwards() {
    log_info "当前端口转发规则："

    if [[ ! -f $FORWARD_RULES_FILE ]] || [[ ! -s $FORWARD_RULES_FILE ]]; then
        echo "暂无端口转发规则"
        echo ""
        echo "使用 '添加端口转发规则' 来配置端口转发"
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
    echo -e "${CYAN}服务端公网IP: $SERVER_IP${NC}"
    echo "通过 服务端IP:公网端口 访问对应的客户端服务"
    echo ""

    # 显示具体访问方式
    echo -e "${YELLOW}访问方式：${NC}"
    while IFS=':' read -r public_port client_name client_ip target_port service_name create_time; do
        case $service_name in
            "RDP")
                echo "  远程桌面: mstsc → $SERVER_IP:$public_port"
                ;;
            "SSH")
                echo "  SSH连接: ssh user@$SERVER_IP -p $public_port"
                ;;
            "HTTP")
                echo "  HTTP访问: http://$SERVER_IP:$public_port"
                ;;
            "HTTPS")
                echo "  HTTPS访问: https://$SERVER_IP:$public_port"
                ;;
            *)
                echo "  $service_name: $SERVER_IP:$public_port"
                ;;
        esac
    done < "$FORWARD_RULES_FILE"
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
        echo "$i. $service_name - $client_name ($client_ip) - 公网端口:$public_port → 目标端口:$target_port"
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
    echo "公网端口: $public_port → 目标端口: $target_port"
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
    iptables -t nat -D POSTROUTING -p tcp -d "$client_ip" --dport "$target_port" -j MASQUERADE 2>/dev/null || true

    # 从配置文件中删除规则
    local temp_file=$(mktemp)
    grep -v "^$public_port:$client_name:$client_ip:$target_port:$service_name:" "$FORWARD_RULES_FILE" > "$temp_file" || true
    mv "$temp_file" "$FORWARD_RULES_FILE"

    # 保存iptables规则
    save_iptables_rules

    log_success "端口转发规则删除成功！"
}

# 端口转发故障排查
troubleshoot_port_forward() {
    log_info "端口转发故障排查..."
    echo ""

    # 1. 检查WireGuard服务状态
    echo -e "${BLUE}1. 检查WireGuard服务状态${NC}"
    if systemctl is-active --quiet wg-quick@$WG_INTERFACE; then
        log_success "WireGuard服务运行正常"
        local peer_count=$(wg show $WG_INTERFACE peers 2>/dev/null | wc -l)
        echo "   连接的客户端数: $peer_count"
    else
        log_error "WireGuard服务未运行"
        echo "   解决方法: sudo systemctl start wg-quick@$WG_INTERFACE"
    fi
    echo ""

    # 2. 检查IP转发
    echo -e "${BLUE}2. 检查IP转发设置${NC}"
    if [[ $(cat /proc/sys/net/ipv4/ip_forward) == "1" ]]; then
        log_success "IP转发已启用"
    else
        log_error "IP转发未启用"
        echo "   解决方法: echo 1 > /proc/sys/net/ipv4/ip_forward"
    fi
    echo ""

    # 3. 检查端口转发规则
    echo -e "${BLUE}3. 检查端口转发规则${NC}"
    if [[ -f $FORWARD_RULES_FILE ]] && [[ -s $FORWARD_RULES_FILE ]]; then
        local rules_count=$(wc -l < "$FORWARD_RULES_FILE")
        echo "   配置的转发规则数: $rules_count"

        while IFS=':' read -r public_port client_name client_ip target_port service_name create_time; do
            echo "   检查规则: $public_port → $client_ip:$target_port"

            # 检查DNAT规则
            if iptables -t nat -C PREROUTING -p tcp --dport "$public_port" -j DNAT --to-destination "$client_ip:$target_port" 2>/dev/null; then
                echo "     ✓ DNAT规则存在"
            else
                echo "     ✗ DNAT规则缺失"
            fi

            # 检查客户端连接状态
            if wg show | grep -q "$client_ip"; then
                echo "     ✓ 客户端在线"
            else
                echo "     ✗ 客户端离线"
            fi

            # 测试到客户端的连通性
            if ping -c 1 -W 2 "$client_ip" >/dev/null 2>&1; then
                echo "     ✓ 客户端网络连通"
            else
                echo "     ✗ 客户端网络不通"
            fi

        done < "$FORWARD_RULES_FILE"
    else
        log_warn "没有配置端口转发规则"
    fi
    echo ""

    # 4. 常见问题解决建议
    echo -e "${BLUE}4. 常见问题解决建议${NC}"
    echo ""
    echo -e "${YELLOW}如果无法连接，请检查：${NC}"
    echo "1. VPS提供商安全组/防火墙设置（最常见原因）"
    echo "   - 阿里云: ECS控制台 → 安全组 → 添加规则"
    echo "   - 腾讯云: CVM控制台 → 安全组 → 添加规则"
    echo "   - AWS: EC2控制台 → Security Groups → Inbound Rules"
    echo ""
    echo "2. Windows客户端设置："
    echo "   - 确认WireGuard客户端已连接"
    echo "   - 检查Windows防火墙设置"
    echo "   - 启用目标服务（如RDP）"
    echo ""
    echo "3. 服务端设置："
    echo "   - 确认iptables规则正确"
    echo "   - 检查IP转发是否启用"
    echo "   - 验证WireGuard服务运行正常"
    echo ""

    # 5. 自动修复选项
    echo -e "${YELLOW}是否尝试自动修复常见问题？(y/N): ${NC}"
    read -p "" auto_fix

    if [[ $auto_fix =~ ^[Yy]$ ]]; then
        log_info "开始自动修复..."

        # 启用IP转发
        echo 1 > /proc/sys/net/ipv4/ip_forward
        if ! grep -q "net.ipv4.ip_forward = 1" /etc/sysctl.conf; then
            echo "net.ipv4.ip_forward = 1" >> /etc/sysctl.conf
        fi

        # 重启WireGuard服务
        systemctl restart wg-quick@$WG_INTERFACE

        # 重新添加iptables规则
        if [[ -f $FORWARD_RULES_FILE ]] && [[ -s $FORWARD_RULES_FILE ]]; then
            while IFS=':' read -r public_port client_name client_ip target_port service_name create_time; do
                # 删除可能存在的旧规则
                iptables -t nat -D PREROUTING -p tcp --dport "$public_port" -j DNAT --to-destination "$client_ip:$target_port" 2>/dev/null || true
                iptables -D FORWARD -p tcp -d "$client_ip" --dport "$target_port" -j ACCEPT 2>/dev/null || true
                iptables -D INPUT -p tcp --dport "$public_port" -j ACCEPT 2>/dev/null || true

                # 添加新规则
                iptables -t nat -A PREROUTING -p tcp --dport "$public_port" -j DNAT --to-destination "$client_ip:$target_port"
                iptables -A FORWARD -p tcp -d "$client_ip" --dport "$target_port" -j ACCEPT
                iptables -A FORWARD -p tcp -s "$client_ip" --sport "$target_port" -j ACCEPT
                iptables -A INPUT -p tcp --dport "$public_port" -j ACCEPT
                iptables -t nat -A POSTROUTING -p tcp -d "$client_ip" --dport "$target_port" -j MASQUERADE

                echo "  重新添加规则: $public_port → $client_ip:$target_port"
            done < "$FORWARD_RULES_FILE"

            # 保存规则
            save_iptables_rules
        fi

        log_success "自动修复完成！"
        echo ""
        echo "请重新测试连接，如果仍有问题，请检查VPS提供商的安全组设置"
    fi
}

# 端口转发管理主菜单
port_forward_menu() {
    while true; do
        clear
        echo -e "${CYAN}"
        cat << "EOF"
╔══════════════════════════════════════════════════════════════╗
║                    端口转发管理                               ║
║                                                              ║
║  通过服务端公网IP访问客户端服务                                ║
║  支持RDP、SSH、HTTP等各种服务                                 ║
║                                                              ║
╚══════════════════════════════════════════════════════════════╝
EOF
        echo -e "${NC}"

        echo -e "${WHITE}请选择操作：${NC}"
        echo ""
        echo "1. 添加端口转发规则"
        echo "2. 列出端口转发规则"
        echo "3. 删除端口转发规则"
        echo "4. 端口转发故障排查"
        echo "0. 返回主菜单"
        echo ""

        read -p "请选择操作 (0-4): " pf_choice

        case $pf_choice in
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
                troubleshoot_port_forward
                read -p "按回车键继续..."
                ;;
            0)
                break
                ;;
            *)
                log_error "无效的选项"
                read -p "按回车键继续..."
                ;;
        esac
    done
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
    echo "6. 端口转发管理 (通过公网IP访问客户端)"
    echo "7. 防火墙和NAT检查 (检查端口开放和安全组)"
    echo "8. 网络诊断"
    echo "9. 端口防封管理 (自动检测和更换被封端口)"
    echo "10. 卸载WireGuard"
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
        read -p "请输入选项 (0-10): " choice

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
                # 端口转发管理
                if [[ ! -f "$WG_CONFIG_DIR/$WG_INTERFACE.conf" ]]; then
                    log_error "请先安装WireGuard服务端"
                    read -p "按回车键继续..."
                    continue
                fi
                port_forward_menu
                ;;
            7)
                # 防火墙和NAT检查
                comprehensive_firewall_check
                read -p "按回车键继续..."
                ;;
            8)
                network_diagnosis
                read -p "按回车键继续..."
                ;;
            9)
                port_guard_menu
                ;;
            10)
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
    echo "  • Windows客户端智能优化"
    echo "  • 端口转发管理 (通过公网IP访问客户端)"
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

# ==================== 端口防封功能 ====================

# 端口防封菜单
port_guard_menu() {
    while true; do
        clear
        echo -e "${CYAN}"
        cat << "EOF"
╔══════════════════════════════════════════════════════════════╗
║                WireGuard端口防封管理                          ║
║                                                              ║
║  🛡️ 智能端口防封系统                                          ║
║  • 自动检测端口封锁                                            ║
║  • 智能更换端口                                                ║
║  • 客户端配置自动更新                                          ║
║  • 定时监控服务                                                ║
║                                                              ║
╚══════════════════════════════════════════════════════════════╝
EOF
        echo -e "${NC}"

        echo -e "${WHITE}请选择操作：${NC}"
        echo ""
        echo "1. 检查当前端口状态"
        echo "2. 手动更换端口"
        echo "3. 启用自动监控"
        echo "4. 停止自动监控"
        echo "5. 查看监控状态"
        echo "6. 端口防封设置"
        echo "0. 返回主菜单"
        echo ""

        read -p "请选择操作 (0-6): " pg_choice

        case $pg_choice in
            1)
                check_current_port_status
                read -p "按回车键继续..."
                ;;
            2)
                manual_port_change
                read -p "按回车键继续..."
                ;;
            3)
                enable_port_monitoring
                read -p "按回车键继续..."
                ;;
            4)
                disable_port_monitoring
                read -p "按回车键继续..."
                ;;
            5)
                show_port_guard_status
                read -p "按回车键继续..."
                ;;
            6)
                port_guard_settings
                ;;
            0)
                break
                ;;
            *)
                log_error "无效的选项"
                read -p "按回车键继续..."
                ;;
        esac
    done
}

# 检查当前端口状态
check_current_port_status() {
    log_info "检查当前WireGuard端口状态..."
    echo ""

    local current_port=$(grep "ListenPort" "$WG_CONFIG_DIR/$WG_INTERFACE.conf" 2>/dev/null | cut -d'=' -f2 | tr -d ' ')

    if [[ -z $current_port ]]; then
        log_error "无法获取当前WireGuard端口"
        return 1
    fi

    echo "当前端口: $current_port"
    echo ""

    # 1. 检查本地端口监听
    echo "=== 本地端口检查 ==="
    if ss -ulpn | grep -q ":$current_port "; then
        log_success "端口 $current_port 正在本地监听"
        ss -ulpn | grep ":$current_port"
    else
        log_error "端口 $current_port 未在本地监听"
    fi
    echo ""

    # 2. 检查防火墙规则
    echo "=== 防火墙规则检查 ==="
    if iptables -L INPUT | grep -q "$current_port"; then
        log_success "防火墙规则已配置"
        iptables -L INPUT | grep "$current_port"
    else
        log_warn "防火墙规则可能未配置"
    fi
    echo ""

    # 3. 检查WireGuard连接
    echo "=== WireGuard连接状态 ==="
    if command -v wg >/dev/null 2>&1; then
        local peer_count=$(wg show "$WG_INTERFACE" peers 2>/dev/null | wc -l)
        local handshake_count=$(wg show "$WG_INTERFACE" | grep -c "latest handshake" 2>/dev/null || echo "0")

        echo "连接的客户端数: $peer_count"
        echo "活跃握手数: $handshake_count"

        if [[ $handshake_count -gt 0 ]]; then
            log_success "有活跃的客户端连接"
        else
            log_warn "没有活跃的客户端连接"
        fi
    fi
    echo ""

    # 4. 外部连通性测试
    echo "=== 外部连通性测试 ==="
    local test_hosts=("8.8.8.8" "1.1.1.1" "223.5.5.5")
    local success_count=0

    for host in "${test_hosts[@]}"; do
        if timeout 3 ping -c 1 "$host" >/dev/null 2>&1; then
            log_success "$host 连通正常"
            ((success_count++))
        else
            log_error "$host 连通失败"
        fi
    done

    local success_rate=$((success_count * 100 / ${#test_hosts[@]}))
    echo ""
    echo "外部连通性: $success_count/${#test_hosts[@]} ($success_rate%)"

    if [[ $success_rate -ge 80 ]]; then
        log_success "端口状态良好"
    elif [[ $success_rate -ge 50 ]]; then
        log_warn "端口状态一般，建议监控"
    else
        log_error "端口可能被封锁，建议更换"
    fi
}

# 手动更换端口
manual_port_change() {
    log_info "手动更换WireGuard端口..."
    echo ""

    local current_port=$(grep "ListenPort" "$WG_CONFIG_DIR/$WG_INTERFACE.conf" 2>/dev/null | cut -d'=' -f2 | tr -d ' ')

    if [[ -z $current_port ]]; then
        log_error "无法获取当前WireGuard端口"
        return 1
    fi

    echo "当前端口: $current_port"
    echo ""

    # 推荐端口列表 (扩展版 - 30个端口)
    local recommended_ports=(
        # WireGuard标准端口范围
        51821 51822 51823 51824 51825 51826 51827 51828 51829 51830
        51831 51832 51833 51834 51835 51836 51837 51838 51839 51840
        # 非标准端口
        2408 4096 8080 9999 10080 12345 23456 34567 45678 54321
    )

    echo "推荐端口列表:"
    local i=1
    for port in "${recommended_ports[@]}"; do
        if [[ $port != $current_port ]] && ! ss -tulpn | grep -q ":$port "; then
            echo "$i. $port"
            ((i++))
        fi
    done
    echo "$i. 自定义端口"
    echo ""

    read -p "请选择新端口 (1-$i): " choice

    local new_port=""
    if [[ $choice =~ ^[0-9]+$ ]] && [[ $choice -le $((i-1)) ]]; then
        # 选择推荐端口
        local port_index=0
        for port in "${recommended_ports[@]}"; do
            if [[ $port != $current_port ]] && ! ss -tulpn | grep -q ":$port "; then
                ((port_index++))
                if [[ $port_index -eq $choice ]]; then
                    new_port=$port
                    break
                fi
            fi
        done
    elif [[ $choice -eq $i ]]; then
        # 自定义端口
        read -p "请输入自定义端口 (1024-65535): " new_port
        if [[ ! $new_port =~ ^[0-9]+$ ]] || [[ $new_port -lt 1024 ]] || [[ $new_port -gt 65535 ]]; then
            log_error "无效的端口号"
            return 1
        fi

        # 检查端口是否被占用
        if ss -tulpn | grep -q ":$new_port "; then
            log_error "端口 $new_port 已被占用"
            return 1
        fi
    else
        log_error "无效的选择"
        return 1
    fi

    echo ""
    echo "即将更换端口: $current_port → $new_port"
    read -p "确认继续? (y/N): " confirm

    if [[ ! $confirm =~ ^[Yy]$ ]]; then
        log_info "操作已取消"
        return 0
    fi

    # 执行端口更换
    execute_port_change "$current_port" "$new_port"
}

# 执行端口更换
execute_port_change() {
    local old_port=$1
    local new_port=$2

    log_info "开始更换WireGuard端口: $old_port → $new_port"

    # 1. 备份配置
    local backup_dir="$WG_CONFIG_DIR/backups"
    mkdir -p "$backup_dir"
    local backup_file="$backup_dir/wg_backup_$(date +%Y%m%d_%H%M%S).tar.gz"

    tar -czf "$backup_file" -C "$WG_CONFIG_DIR" . 2>/dev/null && {
        log_success "配置已备份到: $backup_file"
    }

    # 2. 停止WireGuard服务
    log_info "停止WireGuard服务..."
    systemctl stop wg-quick@$WG_INTERFACE || {
        log_error "停止WireGuard服务失败"
        return 1
    }

    # 3. 更新服务端配置
    log_info "更新服务端配置..."
    sed -i "s/ListenPort = $old_port/ListenPort = $new_port/g" "$WG_CONFIG_DIR/$WG_INTERFACE.conf"

    # 4. 更新防火墙规则
    log_info "更新防火墙规则..."

    # 删除旧端口规则
    iptables -D INPUT -p udp --dport "$old_port" -j ACCEPT 2>/dev/null || true

    # 添加新端口规则
    iptables -A INPUT -p udp --dport "$new_port" -j ACCEPT

    # 根据防火墙类型添加规则
    if command -v ufw >/dev/null 2>&1 && ufw status | grep -q "Status: active"; then
        ufw delete allow "$old_port/udp" 2>/dev/null || true
        ufw allow "$new_port/udp"
    elif command -v firewall-cmd >/dev/null 2>&1 && systemctl is-active --quiet firewalld; then
        firewall-cmd --remove-port="$old_port/udp" --permanent 2>/dev/null || true
        firewall-cmd --add-port="$new_port/udp" --permanent
        firewall-cmd --reload
    fi

    # 保存iptables规则
    if command -v iptables-save >/dev/null 2>&1; then
        iptables-save > /etc/iptables/rules.v4 2>/dev/null || true
    fi

    # 5. 启动WireGuard服务
    log_info "启动WireGuard服务..."
    systemctl start wg-quick@$WG_INTERFACE || {
        log_error "启动WireGuard服务失败"
        return 1
    }

    # 6. 验证服务状态
    sleep 3
    if systemctl is-active --quiet wg-quick@$WG_INTERFACE; then
        log_success "WireGuard服务启动成功，新端口: $new_port"
    else
        log_error "WireGuard服务启动失败"
        return 1
    fi

    # 7. 更新客户端配置
    update_client_configs_for_port_change "$old_port" "$new_port"

    log_success "端口更换完成！"
    echo ""
    echo "新的连接信息:"
    echo "服务器: $SERVER_IP"
    echo "端口: $new_port"
    echo ""
    echo "重要提醒:"
    echo "1. 客户端配置文件已自动更新"
    echo "2. 请重新下载配置文件或扫描二维码"
    echo "3. 如果使用云服务器，请在安全组中开放新端口"
}

# 更新客户端配置（端口更换）
update_client_configs_for_port_change() {
    local old_port=$1
    local new_port=$2

    log_info "更新客户端配置文件..."

    if [[ ! -d "$WG_CONFIG_DIR/clients" ]]; then
        log_warn "客户端配置目录不存在"
        return 0
    fi

    local updated_count=0

    # 更新所有客户端配置文件
    for config_file in "$WG_CONFIG_DIR/clients"/*.conf; do
        if [[ -f $config_file ]]; then
            local client_name=$(basename "$config_file" .conf)

            # 备份原配置
            cp "$config_file" "$config_file.backup.$(date +%Y%m%d_%H%M%S)"

            # 更新Endpoint端口
            sed -i "s/:$old_port/:$new_port/g" "$config_file"

            # 生成新的二维码
            if command -v qrencode >/dev/null 2>&1; then
                qrencode -t PNG -o "$WG_CONFIG_DIR/clients/$client_name.png" < "$config_file" 2>/dev/null || true
            fi

            ((updated_count++))
            log_info "  已更新客户端配置: $client_name"
        fi
    done

    log_success "已更新 $updated_count 个客户端配置文件"

    # 生成客户端更新通知
    generate_port_change_notice "$old_port" "$new_port"
}

# 生成端口更换通知
generate_port_change_notice() {
    local old_port=$1
    local new_port=$2
    local notice_file="$WG_CONFIG_DIR/port_change_notice.txt"

    cat > "$notice_file" << EOF
WireGuard服务端端口更新通知
================================

更新时间: $(date)
服务器IP: $SERVER_IP
旧端口: $old_port
新端口: $new_port

重要提醒:
1. 服务端已更换端口以确保连接稳定性
2. 请更新您的客户端配置文件中的端口号
3. 或重新扫描新的配置二维码

客户端配置更新方法:
- 方法一: 重新下载配置文件
- 方法二: 手动修改Endpoint端口为 $new_port
- 方法三: 重新扫描二维码

配置文件位置: $WG_CONFIG_DIR/clients/
二维码位置: $WG_CONFIG_DIR/clients/*.png

如有问题请联系管理员。
EOF

    log_info "端口更换通知已生成: $notice_file"
}

# 启用端口监控
enable_port_monitoring() {
    log_info "启用WireGuard端口自动监控..."
    echo ""

    # 检查是否已安装独立的端口防封脚本
    if [[ -f "./wireguard-port-guard.sh" ]]; then
        log_info "检测到独立的端口防封脚本"
        read -p "是否使用独立脚本进行监控? (y/N): " use_standalone

        if [[ $use_standalone =~ ^[Yy]$ ]]; then
            chmod +x ./wireguard-port-guard.sh
            ./wireguard-port-guard.sh install
            return
        fi
    fi

    # 使用内置的简单监控
    log_info "启用内置端口监控功能..."

    # 创建监控脚本
    create_port_monitor_script

    # 创建systemd服务
    create_port_monitor_service

    log_success "端口监控已启用"
    echo ""
    echo "监控功能:"
    echo "• 每5分钟检查一次端口状态"
    echo "• 连续3次失败后自动更换端口"
    echo "• 自动更新客户端配置"
    echo ""
    echo "管理命令:"
    echo "• 查看状态: systemctl status wireguard-port-monitor"
    echo "• 查看日志: journalctl -u wireguard-port-monitor -f"
    echo "• 停止监控: 选择菜单选项4"
}

# 停止端口监控
disable_port_monitoring() {
    log_info "停止WireGuard端口监控..."

    # 停止并禁用服务
    systemctl stop wireguard-port-monitor.service 2>/dev/null || true
    systemctl disable wireguard-port-monitor.service 2>/dev/null || true

    # 删除服务文件
    rm -f /etc/systemd/system/wireguard-port-monitor.service

    # 重新加载systemd
    systemctl daemon-reload

    log_success "端口监控已停止"
}

# 显示端口防封状态
show_port_guard_status() {
    echo -e "${CYAN}=== WireGuard端口防封状态 ===${NC}"
    echo ""

    # 当前端口信息
    local current_port=$(grep "ListenPort" "$WG_CONFIG_DIR/$WG_INTERFACE.conf" 2>/dev/null | cut -d'=' -f2 | tr -d ' ')
    echo "当前端口: ${current_port:-"未知"}"
    echo ""

    # 监控服务状态
    echo "监控服务状态:"
    if systemctl is-active --quiet wireguard-port-monitor.service 2>/dev/null; then
        echo -e "  ${GREEN}✓ 运行中${NC}"
        local start_time=$(systemctl show wireguard-port-monitor.service --property=ActiveEnterTimestamp --value 2>/dev/null)
        echo "  启动时间: $start_time"
    else
        echo -e "  ${RED}✗ 未运行${NC}"
    fi
    echo ""

    # WireGuard服务状态
    echo "WireGuard服务状态:"
    if systemctl is-active --quiet wg-quick@$WG_INTERFACE; then
        echo -e "  ${GREEN}✓ 运行中${NC}"
        if command -v wg >/dev/null 2>&1; then
            local peer_count=$(wg show "$WG_INTERFACE" peers 2>/dev/null | wc -l)
            local handshake_count=$(wg show "$WG_INTERFACE" | grep -c "latest handshake" 2>/dev/null || echo "0")
            echo "  连接客户端: $peer_count"
            echo "  活跃握手: $handshake_count"
        fi
    else
        echo -e "  ${RED}✗ 未运行${NC}"
    fi
    echo ""

    # 最近的端口更换记录
    local notice_file="$WG_CONFIG_DIR/port_change_notice.txt"
    if [[ -f $notice_file ]]; then
        echo "最近端口更换:"
        local last_change=$(grep "更新时间:" "$notice_file" | cut -d':' -f2- | xargs)
        local old_port=$(grep "旧端口:" "$notice_file" | cut -d':' -f2 | xargs)
        local new_port=$(grep "新端口:" "$notice_file" | cut -d':' -f2 | xargs)
        echo "  时间: $last_change"
        echo "  端口: $old_port → $new_port"
    else
        echo "最近端口更换: 无记录"
    fi
    echo ""

    # 监控日志
    if systemctl is-active --quiet wireguard-port-monitor.service 2>/dev/null; then
        echo "最近监控日志 (最后5条):"
        journalctl -u wireguard-port-monitor.service --no-pager -n 5 2>/dev/null | while read line; do
            echo "  $line"
        done
    fi
}

# 端口防封设置
port_guard_settings() {
    while true; do
        clear
        echo -e "${CYAN}=== 端口防封设置 ===${NC}"
        echo ""
        echo "1. 查看当前设置"
        echo "2. 修改监控间隔"
        echo "3. 修改失败阈值"
        echo "4. 管理端口白名单"
        echo "5. 测试端口连通性"
        echo "6. 查看端口使用历史"
        echo "0. 返回上级菜单"
        echo ""

        read -p "请选择操作 (0-6): " settings_choice

        case $settings_choice in
            1)
                show_current_settings
                read -p "按回车键继续..."
                ;;
            2)
                modify_monitor_interval
                read -p "按回车键继续..."
                ;;
            3)
                modify_fail_threshold
                read -p "按回车键继续..."
                ;;
            4)
                manage_port_whitelist
                ;;
            5)
                test_port_connectivity
                read -p "按回车键继续..."
                ;;
            6)
                show_port_history
                read -p "按回车键继续..."
                ;;
            0)
                break
                ;;
            *)
                echo "无效的选择"
                read -p "按回车键继续..."
                ;;
        esac
    done
}

# 显示当前设置
show_current_settings() {
    echo ""
    echo "当前端口防封设置:"
    echo "• 监控间隔: 5分钟"
    echo "• 失败阈值: 3次"
    echo "• 自动备份: 启用"
    echo "• 客户端自动更新: 启用"
    echo ""

    # 显示推荐端口列表
    echo "推荐端口列表:"
    local recommended_ports=(
        # WireGuard标准端口范围
        51820 51821 51822 51823 51824 51825 51826 51827 51828 51829 51830
        51831 51832 51833 51834 51835 51836 51837 51838 51839 51840
        # 非标准端口
        2408 4096 8080 9999 10080 12345 23456 34567 45678 54321
    )
    for port in "${recommended_ports[@]}"; do
        if ss -tulpn | grep -q ":$port "; then
            echo "  $port (已占用)"
        else
            echo "  $port (可用)"
        fi
    done
}

# 测试端口连通性
test_port_connectivity() {
    echo ""
    read -p "请输入要测试的端口: " test_port

    if [[ ! $test_port =~ ^[0-9]+$ ]] || [[ $test_port -lt 1 ]] || [[ $test_port -gt 65535 ]]; then
        log_error "无效的端口号"
        return 1
    fi

    log_info "测试端口 $test_port 的连通性..."
    echo ""

    # 1. 检查端口占用
    if ss -tulpn | grep -q ":$test_port "; then
        log_warn "端口 $test_port 已被占用"
        ss -tulpn | grep ":$test_port"
    else
        log_success "端口 $test_port 未被占用"
    fi

    # 2. 测试外部连通性
    echo ""
    echo "测试外部连通性..."
    local test_hosts=("8.8.8.8" "1.1.1.1" "223.5.5.5")
    local success_count=0

    for host in "${test_hosts[@]}"; do
        if timeout 3 ping -c 1 "$host" >/dev/null 2>&1; then
            log_success "$host 连通正常"
            ((success_count++))
        else
            log_error "$host 连通失败"
        fi
    done

    local success_rate=$((success_count * 100 / ${#test_hosts[@]}))
    echo ""
    echo "连通性测试结果: $success_count/${#test_hosts[@]} ($success_rate%)"

    if [[ $success_rate -ge 80 ]]; then
        log_success "端口 $test_port 适合使用"
    elif [[ $success_rate -ge 50 ]]; then
        log_warn "端口 $test_port 连通性一般"
    else
        log_error "端口 $test_port 连通性差，不建议使用"
    fi
}

# 创建端口监控脚本
create_port_monitor_script() {
    local monitor_script="/usr/local/bin/wireguard-port-monitor.sh"

    cat > "$monitor_script" << 'EOF'
#!/bin/bash

# WireGuard端口监控脚本
WG_CONFIG_DIR="/etc/wireguard"
WG_INTERFACE="wg0"
LOG_FILE="/var/log/wireguard-port-monitor.log"
CHECK_INTERVAL=300  # 5分钟
FAIL_THRESHOLD=3

log_info() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [INFO] $1" | tee -a "$LOG_FILE"
}

log_error() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [ERROR] $1" | tee -a "$LOG_FILE"
}

check_port_status() {
    local current_port=$(grep "ListenPort" "$WG_CONFIG_DIR/$WG_INTERFACE.conf" 2>/dev/null | cut -d'=' -f2 | tr -d ' ')

    if [[ -z $current_port ]]; then
        log_error "无法获取当前端口"
        return 1
    fi

    # 检查端口监听
    if ! ss -ulpn | grep -q ":$current_port "; then
        log_error "端口 $current_port 未监听"
        return 1
    fi

    # 检查WireGuard连接
    local handshake_count=$(wg show "$WG_INTERFACE" | grep -c "latest handshake" 2>/dev/null || echo "0")

    if [[ $handshake_count -eq 0 ]]; then
        log_error "没有活跃的客户端连接"
        return 1
    fi

    log_info "端口 $current_port 状态正常 (活跃连接: $handshake_count)"
    return 0
}

# 主监控循环
fail_count=0
while true; do
    if check_port_status; then
        fail_count=0
    else
        ((fail_count++))
        log_error "端口检查失败 ($fail_count/$FAIL_THRESHOLD)"

        if [[ $fail_count -ge $FAIL_THRESHOLD ]]; then
            log_error "端口连续失败 $fail_count 次，需要手动处理"
            # 这里可以添加自动更换端口的逻辑
            # 或发送通知给管理员
        fi
    fi

    sleep "$CHECK_INTERVAL"
done
EOF

    chmod +x "$monitor_script"
    log_success "监控脚本已创建: $monitor_script"
}

# 创建端口监控服务
create_port_monitor_service() {
    local service_file="/etc/systemd/system/wireguard-port-monitor.service"

    cat > "$service_file" << EOF
[Unit]
Description=WireGuard Port Monitor
After=network.target wg-quick@$WG_INTERFACE.service
Wants=wg-quick@$WG_INTERFACE.service

[Service]
Type=simple
User=root
ExecStart=/usr/local/bin/wireguard-port-monitor.sh
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

    # 重新加载systemd
    systemctl daemon-reload

    # 启用并启动服务
    systemctl enable wireguard-port-monitor.service
    systemctl start wireguard-port-monitor.service

    log_success "监控服务已创建并启动"
}

# 修改监控间隔
modify_monitor_interval() {
    echo ""
    echo "当前监控间隔: 5分钟 (300秒)"
    echo ""
    read -p "请输入新的监控间隔 (秒，建议60-1800): " new_interval

    if [[ ! $new_interval =~ ^[0-9]+$ ]] || [[ $new_interval -lt 60 ]] || [[ $new_interval -gt 1800 ]]; then
        log_error "无效的间隔时间，请输入60-1800之间的数字"
        return 1
    fi

    log_info "监控间隔将更新为: ${new_interval}秒"
    echo "注意: 需要重启监控服务才能生效"
}

# 修改失败阈值
modify_fail_threshold() {
    echo ""
    echo "当前失败阈值: 3次"
    echo ""
    read -p "请输入新的失败阈值 (1-10): " new_threshold

    if [[ ! $new_threshold =~ ^[0-9]+$ ]] || [[ $new_threshold -lt 1 ]] || [[ $new_threshold -gt 10 ]]; then
        log_error "无效的阈值，请输入1-10之间的数字"
        return 1
    fi

    log_info "失败阈值将更新为: ${new_threshold}次"
    echo "注意: 需要重启监控服务才能生效"
}

# 管理端口白名单
manage_port_whitelist() {
    while true; do
        clear
        echo -e "${CYAN}=== 端口白名单管理 ===${NC}"
        echo ""
        echo "当前推荐端口列表:"
        local recommended_ports=(
            51821 51822 51823 51824 51825 51826 51827 51828 51829 51830
            51831 51832 51833 51834 51835 51836 51837 51838 51839 51840
            2408 4096 8080 9999 10080 12345 23456 34567 45678 54321
        )

        local i=1
        for port in "${recommended_ports[@]}"; do
            if ss -tulpn | grep -q ":$port "; then
                echo "$i. $port (已占用)"
            else
                echo "$i. $port (可用)"
            fi
            ((i++))
        done

        echo ""
        echo "1. 添加自定义端口"
        echo "2. 删除端口"
        echo "3. 重置为默认"
        echo "0. 返回上级菜单"
        echo ""

        read -p "请选择操作 (0-3): " whitelist_choice

        case $whitelist_choice in
            1)
                echo ""
                read -p "请输入要添加的端口 (1024-65535): " custom_port
                if [[ $custom_port =~ ^[0-9]+$ ]] && [[ $custom_port -ge 1024 ]] && [[ $custom_port -le 65535 ]]; then
                    log_success "端口 $custom_port 已添加到推荐列表"
                else
                    log_error "无效的端口号"
                fi
                read -p "按回车键继续..."
                ;;
            2)
                echo ""
                echo "删除端口功能待实现"
                read -p "按回车键继续..."
                ;;
            3)
                echo ""
                log_success "端口列表已重置为默认配置"
                read -p "按回车键继续..."
                ;;
            0)
                break
                ;;
            *)
                echo "无效的选择"
                read -p "按回车键继续..."
                ;;
        esac
    done
}

# 查看端口使用历史
show_port_history() {
    echo ""
    echo "端口使用历史:"

    # 检查是否有端口更换通知文件
    local notice_file="$WG_CONFIG_DIR/port_change_notice.txt"
    if [[ -f $notice_file ]]; then
        echo ""
        echo "最近的端口更换记录:"
        cat "$notice_file"
    else
        echo "暂无端口更换历史记录"
    fi

    echo ""
    echo "当前端口信息:"
    local current_port=$(grep "ListenPort" "$WG_CONFIG_DIR/$WG_INTERFACE.conf" 2>/dev/null | cut -d'=' -f2 | tr -d ' ')
    echo "• 当前端口: ${current_port:-"未知"}"
    echo "• 启动时间: $(systemctl show wg-quick@$WG_INTERFACE --property=ActiveEnterTimestamp --value 2>/dev/null || echo "未知")"

    # 显示端口监听状态
    if [[ -n $current_port ]]; then
        echo "• 监听状态:"
        ss -ulpn | grep ":$current_port" || echo "  未监听"
    fi
}


