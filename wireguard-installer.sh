#!/bin/bash
# -*- coding: utf-8 -*-

# WireGuard 完整安装脚本
# 支持国内外网络环境，完全交互式操作
# 作者: WireGuard安装助手
# 版本: 1.0.0

# 设置UTF-8编码环境
export LANG=C.UTF-8
export LC_ALL=C.UTF-8

# 调试模式开关
DEBUG_MODE=${DEBUG_MODE:-false}

# 错误处理
set -e
trap 'log_error "脚本在第 $LINENO 行出错，退出码: $?"' ERR

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

# 全局变量
SCRIPT_VERSION="1.0.0"
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
PRIVATE_SUBNET="10.66.0.0/16"  # 使用不常见的私网段
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

# 显示横幅
show_banner() {
    clear
    echo -e "${CYAN}"
    cat << "EOF"
╔══════════════════════════════════════════════════════════════╗
║                    WireGuard 安装助手                        ║
║                                                              ║
║  • 支持国内外网络环境自动适配                                  ║
║  • 完全交互式操作界面                                          ║
║  • 自动网络优化配置                                            ║
║  • 智能私网段选择                                              ║
║  • 服务端客户端一体化管理                                      ║
║                                                              ║
╚══════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
    echo -e "${WHITE}版本: ${SCRIPT_VERSION}${NC}"
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

# 网络环境检测
detect_network_environment() {
    log_info "检测网络环境..."

    # 检测是否在中国大陆
    local china_test_sites=("www.baidu.com" "www.qq.com" "www.163.com")
    local overseas_test_sites=("www.google.com" "www.github.com" "www.cloudflare.com")

    local china_success=0
    local overseas_success=0

    log_info "正在测试网络连通性，请稍候..."

    # 测试中国网站
    for site in "${china_test_sites[@]}"; do
        log_debug "测试中国网站: $site"
        if timeout 3 ping -c 1 -W 2 "$site" >/dev/null 2>&1; then
            ((china_success++))
            log_debug "✓ $site 连通"
        else
            log_debug "✗ $site 不通"
        fi
    done

    # 测试海外网站
    for site in "${overseas_test_sites[@]}"; do
        log_debug "测试海外网站: $site"
        if timeout 3 ping -c 1 -W 2 "$site" >/dev/null 2>&1; then
            ((overseas_success++))
            log_debug "✓ $site 连通"
        else
            log_debug "✗ $site 不通"
        fi
    done

    log_info "网络测试结果: 国内网站 $china_success/3, 海外网站 $overseas_success/3"

    # 判断网络环境
    if [[ $china_success -gt $overseas_success ]]; then
        IS_CHINA_NETWORK=true
        log_info "检测到国内网络环境"
        DNS_SERVERS="223.5.5.5,119.29.29.29"  # 使用国内DNS
    elif [[ $overseas_success -gt 0 ]]; then
        IS_CHINA_NETWORK=false
        log_info "检测到海外网络环境"
        DNS_SERVERS="8.8.8.8,1.1.1.1"  # 使用海外DNS
    else
        # 如果都无法连通，默认使用国内配置
        log_warn "网络检测失败，默认使用国内网络配置"
        IS_CHINA_NETWORK=true
        DNS_SERVERS="223.5.5.5,119.29.29.29"
    fi

    log_info "网络环境检测完成"
}

# 网络连通性测试
test_network_connectivity() {
    log_info "测试网络连通性..."

    # 首先检查基本的网络连通性
    local basic_hosts=("8.8.8.8" "223.5.5.5")
    local basic_success=0

    for host in "${basic_hosts[@]}"; do
        if timeout 3 ping -c 1 -W 2 "$host" >/dev/null 2>&1; then
            ((basic_success++))
            log_debug "✓ $host 连通"
            break  # 只要有一个能通就继续
        fi
    done

    if [[ $basic_success -eq 0 ]]; then
        log_warn "基本网络连通性测试失败，但继续安装..."
        log_warn "如果安装过程中遇到下载问题，请检查网络设置"
        return 0  # 不退出，继续安装
    fi

    # 测试HTTP连接
    local test_urls=()
    if [[ $IS_CHINA_NETWORK == true ]]; then
        test_urls=("http://www.baidu.com" "http://mirrors.aliyun.com")
    else
        test_urls=("http://www.google.com" "http://github.com")
    fi

    local success_count=0
    for url in "${test_urls[@]}"; do
        log_debug "测试HTTP连接: $url"
        if timeout 5 curl -s --connect-timeout 3 "$url" >/dev/null 2>&1; then
            ((success_count++))
            log_info "✓ $url 连接正常"
        else
            log_debug "✗ $url 连接失败"
        fi
    done

    if [[ $success_count -eq 0 ]]; then
        log_warn "HTTP连接测试失败，但基本网络正常，继续安装..."
        log_warn "如果遇到软件包下载问题，可能需要配置代理"
    else
        log_info "网络连通性测试完成 ($success_count/${#test_urls[@]} 成功)"
    fi
}

# 获取服务器公网IP
get_server_ip() {
    log_info "获取服务器公网IP..."
    
    local ip_services=()
    if [[ $IS_CHINA_NETWORK == true ]]; then
        ip_services=("http://members.3322.org/dyndns/getip" "http://ip.cip.cc")
    else
        ip_services=("http://ipv4.icanhazip.com" "http://ifconfig.me/ip")
    fi
    
    for service in "${ip_services[@]}"; do
        SERVER_IP=$(timeout 10 curl -s "$service" 2>/dev/null | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$')
        if [[ -n $SERVER_IP ]]; then
            log_info "服务器公网IP: $SERVER_IP"
            return 0
        fi
    done
    
    log_error "无法获取服务器公网IP"
    read -p "请手动输入服务器公网IP: " SERVER_IP
    if [[ ! $SERVER_IP =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        log_error "IP地址格式不正确"
        exit 1
    fi
}

# 检查端口占用
check_port_usage() {
    local port=$1
    if ss -tulpn | grep ":$port " >/dev/null 2>&1; then
        return 1
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
    if ip route | grep -q "$subnet_base"; then
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
        local last_octet=$(echo "$subnet_base" | cut -d'.' -f4)
        PRIVATE_SUBNET_IP=$(echo "$subnet_base" | sed 's/\.[0-9]*$/\.1/')

        log_info "私网段设置为: $PRIVATE_SUBNET"
        log_info "服务器内网IP: $PRIVATE_SUBNET_IP"
        break
    done
}

# 安装依赖包
install_dependencies() {
    log_info "安装系统依赖..."

    case $SYSTEM_TYPE in
        ubuntu|debian)
            # 更新包列表
            if [[ $IS_CHINA_NETWORK == true ]]; then
                log_info "配置国内镜像源..."
                # 备份原始sources.list
                cp /etc/apt/sources.list /etc/apt/sources.list.backup

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
            apt install -y wireguard wireguard-tools iptables resolvconf qrencode curl wget net-tools
            ;;

        centos|rhel|fedora)
            if [[ $IS_CHINA_NETWORK == true ]]; then
                log_info "配置国内镜像源..."
                if [[ $SYSTEM_TYPE == "centos" ]]; then
                    sed -e 's|^mirrorlist=|#mirrorlist=|g' \
                        -e 's|^#baseurl=http://mirror.centos.org|baseurl=https://mirrors.aliyun.com|g' \
                        -i.bak /etc/yum.repos.d/CentOS-*.repo
                fi
            fi

            if command -v dnf >/dev/null 2>&1; then
                dnf install -y epel-release
                dnf install -y wireguard-tools iptables qrencode curl wget net-tools
            else
                yum install -y epel-release
                yum install -y wireguard-tools iptables qrencode curl wget net-tools
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

# 配置系统优化
configure_system_optimization() {
    log_info "配置系统网络优化..."

    # 启用IP转发
    echo 'net.ipv4.ip_forward = 1' >> /etc/sysctl.conf
    echo 'net.ipv6.conf.all.forwarding = 1' >> /etc/sysctl.conf

    # 针对国内网络的优化
    if [[ $IS_CHINA_NETWORK == true ]]; then
        log_info "应用国内网络优化配置..."

        cat >> /etc/sysctl.conf << EOF

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
    sysctl -p

    log_info "系统优化配置完成"
}

# 配置防火墙
configure_firewall() {
    log_info "配置防火墙规则..."

    # 检测防火墙类型
    if command -v ufw >/dev/null 2>&1 && ufw status | grep -q "Status: active"; then
        log_info "配置UFW防火墙..."
        ufw allow "$WG_PORT"/udp
        ufw allow ssh
    elif command -v firewall-cmd >/dev/null 2>&1; then
        log_info "配置firewalld防火墙..."
        firewall-cmd --permanent --add-port="$WG_PORT"/udp
        firewall-cmd --permanent --add-masquerade
        firewall-cmd --reload
    else
        log_info "配置iptables防火墙..."
        # 添加iptables规则
        iptables -A INPUT -p udp --dport "$WG_PORT" -j ACCEPT
        iptables -A FORWARD -i "$WG_INTERFACE" -j ACCEPT
        iptables -A FORWARD -o "$WG_INTERFACE" -j ACCEPT
        iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE

        # 保存iptables规则
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
    systemctl enable wg-quick@$WG_INTERFACE
    systemctl start wg-quick@$WG_INTERFACE

    # 检查服务状态
    if systemctl is-active --quiet wg-quick@$WG_INTERFACE; then
        log_info "WireGuard服务启动成功"
    else
        log_error "WireGuard服务启动失败"
        systemctl status wg-quick@$WG_INTERFACE
        exit 1
    fi
}

# 生成客户端配置
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
[Peer]
PublicKey = $client_public_key
AllowedIPs = $client_ip/32

EOF

    # 重启WireGuard服务
    systemctl restart wg-quick@$WG_INTERFACE

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

# 添加客户端
add_client() {
    log_info "添加新客户端..."

    # 获取客户端名称
    while true; do
        read -p "请输入客户端名称: " client_name
        if [[ -z $client_name ]]; then
            log_error "客户端名称不能为空"
            continue
        fi

        if [[ -f "$WG_CONFIG_DIR/clients/$client_name.conf" ]]; then
            log_error "客户端 $client_name 已存在"
            continue
        fi

        break
    done

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

    generate_client_config "$client_name" "$next_ip"
    ((CLIENT_COUNT++))
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
    printf "%-20s %-15s %-10s\n" "客户端名称" "IP地址" "状态"
    echo "================================================"

    for config_file in "$client_dir"/*.conf; do
        if [[ -f $config_file ]]; then
            local client_name=$(basename "$config_file" .conf)
            local client_ip=$(grep "Address" "$config_file" | cut -d'=' -f2 | cut -d'/' -f1 | tr -d ' ')
            local status="离线"

            # 检查客户端是否在线（通过WireGuard状态）
            if wg show | grep -q "$client_ip"; then
                status="在线"
            fi

            printf "%-20s %-15s %-10s\n" "$client_name" "$client_ip" "$status"
        fi
    done
    echo ""
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

    # 获取客户端公钥
    local client_public_key=$(grep "PublicKey" "$client_dir/$client_name.conf" | cut -d'=' -f2 | tr -d ' ')

    # 从服务端配置中删除客户端
    if [[ -n $client_public_key ]]; then
        # 创建临时文件
        local temp_file=$(mktemp)
        local skip_peer=false

        while IFS= read -r line; do
            if [[ $line == "[Peer]" ]]; then
                skip_peer=false
                echo "$line" >> "$temp_file"
            elif [[ $skip_peer == false && $line =~ ^PublicKey.*$client_public_key ]]; then
                skip_peer=true
                # 删除这个Peer块，不写入临时文件
                continue
            elif [[ $skip_peer == true && ($line == "[Peer]" || $line =~ ^\[.*\]$) ]]; then
                skip_peer=false
                echo "$line" >> "$temp_file"
            elif [[ $skip_peer == false ]]; then
                echo "$line" >> "$temp_file"
            fi
        done < "$WG_CONFIG_DIR/$WG_INTERFACE.conf"

        mv "$temp_file" "$WG_CONFIG_DIR/$WG_INTERFACE.conf"
    fi

    # 删除客户端配置文件
    rm -f "$client_dir/$client_name.conf"

    # 重启WireGuard服务
    systemctl restart wg-quick@$WG_INTERFACE

    log_info "客户端 $client_name 删除完成"
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

# 备份配置
backup_config() {
    log_info "备份WireGuard配置..."

    local backup_dir="/root/wireguard-backup"
    local backup_file="$backup_dir/wireguard-backup-$(date +%Y%m%d-%H%M%S).tar.gz"

    mkdir -p "$backup_dir"

    # 创建备份
    tar -czf "$backup_file" -C / etc/wireguard

    if [[ -f $backup_file ]]; then
        log_info "配置备份完成: $backup_file"
    else
        log_error "配置备份失败"
    fi
}

# 恢复配置
restore_config() {
    log_info "恢复WireGuard配置..."

    local backup_dir="/root/wireguard-backup"
    if [[ ! -d $backup_dir ]] || [[ -z $(ls -A "$backup_dir" 2>/dev/null) ]]; then
        log_warn "没有找到备份文件"
        return
    fi

    echo "可用的备份文件："
    local backups=()
    local i=1
    for backup_file in "$backup_dir"/*.tar.gz; do
        if [[ -f $backup_file ]]; then
            backups+=("$backup_file")
            echo "$i. $(basename "$backup_file")"
            ((i++))
        fi
    done

    read -p "请选择要恢复的备份编号: " choice
    if [[ ! $choice =~ ^[0-9]+$ ]] || [[ $choice -lt 1 ]] || [[ $choice -gt ${#backups[@]} ]]; then
        log_error "无效的选择"
        return
    fi

    local backup_file="${backups[$((choice-1))]}"

    # 确认恢复
    read -p "确认恢复配置？这将覆盖当前配置 (y/N): " confirm
    if [[ ! $confirm =~ ^[Yy]$ ]]; then
        log_info "取消恢复"
        return
    fi

    # 停止服务
    systemctl stop wg-quick@$WG_INTERFACE 2>/dev/null || true

    # 恢复配置
    tar -xzf "$backup_file" -C /

    # 重启服务
    systemctl start wg-quick@$WG_INTERFACE

    log_info "配置恢复完成"
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

    # 备份配置
    if [[ -d $WG_CONFIG_DIR ]]; then
        backup_config
        rm -rf "$WG_CONFIG_DIR"
    fi

    # 清理防火墙规则
    iptables -D INPUT -p udp --dport "$WG_PORT" -j ACCEPT 2>/dev/null || true
    iptables -D FORWARD -i "$WG_INTERFACE" -j ACCEPT 2>/dev/null || true
    iptables -D FORWARD -o "$WG_INTERFACE" -j ACCEPT 2>/dev/null || true
    iptables -t nat -D POSTROUTING -o eth0 -j MASQUERADE 2>/dev/null || true

    log_info "WireGuard卸载完成"
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
    if ss -ulpn | grep -q ":$WG_PORT"; then
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
    echo "6. 备份配置"
    echo "7. 恢复配置"
    echo "8. 网络诊断"
    echo "9. 卸载WireGuard"
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

        # 备份现有配置
        backup_config
    fi

    # 系统检测
    detect_system
    detect_network_environment
    test_network_connectivity
    get_server_ip

    # 配置选择
    select_wireguard_port
    select_private_subnet

    # 安装和配置
    install_dependencies
    generate_keys
    configure_system_optimization
    configure_firewall
    create_server_config
    start_wireguard_service

    echo ""
    log_info "WireGuard服务端安装完成！"
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

# 主程序
main() {
    # 检查root权限
    check_root

    while true; do
        show_main_menu
        read -p "请输入选项 (0-9): " choice

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
                backup_config
                read -p "按回车键继续..."
                ;;
            7)
                restore_config
                read -p "按回车键继续..."
                ;;
            8)
                network_diagnosis
                read -p "按回车键继续..."
                ;;
            9)
                uninstall_wireguard
                read -p "按回车键继续..."
                ;;
            0)
                log_info "感谢使用WireGuard安装助手！"
                exit 0
                ;;
            *)
                log_error "无效的选项，请重新选择"
                read -p "按回车键继续..."
                ;;
        esac
    done
}

# 脚本入口
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
