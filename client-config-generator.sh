#!/bin/bash
# -*- coding: utf-8 -*-

# WireGuard客户端配置批量生成器
# 支持批量生成、导出、管理客户端配置
# 版本: 1.0.0

# 设置UTF-8编码环境
export LANG=C.UTF-8
export LC_ALL=C.UTF-8

set -e

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
CLIENT_DIR="$WG_CONFIG_DIR/clients"
EXPORT_DIR="/root/wireguard-exports"

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

# 检查root权限
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "此脚本需要root权限运行"
        exit 1
    fi
}

# 检查WireGuard是否已安装
check_wireguard_installed() {
    if [[ ! -f "$WG_CONFIG_DIR/$WG_INTERFACE.conf" ]]; then
        log_error "WireGuard服务端未安装，请先运行主安装脚本"
        exit 1
    fi
}

# 获取服务端信息
get_server_info() {
    local server_config="$WG_CONFIG_DIR/$WG_INTERFACE.conf"
    
    SERVER_PUBLIC_KEY=$(grep "PrivateKey" "$server_config" | cut -d'=' -f2 | tr -d ' ' | wg pubkey)
    SERVER_PORT=$(grep "ListenPort" "$server_config" | cut -d'=' -f2 | tr -d ' ')
    SERVER_SUBNET=$(grep "Address" "$server_config" | cut -d'=' -f2 | tr -d ' ')
    
    # 获取服务器公网IP
    SERVER_IP=$(curl -s http://ipv4.icanhazip.com 2>/dev/null || curl -s http://members.3322.org/dyndns/getip 2>/dev/null)
    
    if [[ -z $SERVER_IP ]]; then
        log_error "无法获取服务器公网IP"
        read -p "请手动输入服务器公网IP: " SERVER_IP
    fi
}

# 批量生成客户端配置
batch_generate_clients() {
    log_info "批量生成客户端配置..."
    
    read -p "请输入要生成的客户端数量: " client_count
    if [[ ! $client_count =~ ^[0-9]+$ ]] || [[ $client_count -lt 1 ]]; then
        log_error "请输入有效的数量"
        return 1
    fi
    
    read -p "请输入客户端名称前缀 (默认: client): " name_prefix
    name_prefix=${name_prefix:-client}
    
    # 获取网段信息
    local subnet_base=$(echo "$SERVER_SUBNET" | cut -d'/' -f1 | cut -d'.' -f1-3)
    local subnet_mask=$(echo "$SERVER_SUBNET" | cut -d'/' -f2)
    
    # 创建导出目录
    mkdir -p "$EXPORT_DIR"
    local batch_dir="$EXPORT_DIR/batch-$(date +%Y%m%d-%H%M%S)"
    mkdir -p "$batch_dir"
    
    log_info "开始生成 $client_count 个客户端配置..."
    
    for ((i=1; i<=client_count; i++)); do
        local client_name="${name_prefix}$(printf "%03d" $i)"
        
        # 查找下一个可用IP
        local client_ip=""
        for j in {2..254}; do
            local test_ip="$subnet_base.$j"
            if ! grep -q "$test_ip" "$WG_CONFIG_DIR/$WG_INTERFACE.conf" 2>/dev/null && \
               ! find "$CLIENT_DIR" -name "*.conf" -exec grep -l "$test_ip" {} \; 2>/dev/null | grep -q .; then
                client_ip="$test_ip"
                break
            fi
        done
        
        if [[ -z $client_ip ]]; then
            log_error "没有可用的IP地址用于客户端 $client_name"
            continue
        fi
        
        # 生成客户端密钥对
        local client_private_key=$(wg genkey)
        local client_public_key=$(echo "$client_private_key" | wg pubkey)
        
        # 创建客户端配置文件
        mkdir -p "$CLIENT_DIR"
        cat > "$CLIENT_DIR/$client_name.conf" << EOF
[Interface]
PrivateKey = $client_private_key
Address = $client_ip/$subnet_mask
DNS = 223.5.5.5, 119.29.29.29

[Peer]
PublicKey = $SERVER_PUBLIC_KEY
Endpoint = $SERVER_IP:$SERVER_PORT
AllowedIPs = 0.0.0.0/0
PersistentKeepalive = 25
EOF
        
        # 复制到批量导出目录
        cp "$CLIENT_DIR/$client_name.conf" "$batch_dir/"
        
        # 添加客户端到服务端配置
        cat >> "$WG_CONFIG_DIR/$WG_INTERFACE.conf" << EOF

[Peer]
PublicKey = $client_public_key
AllowedIPs = $client_ip/32
EOF
        
        # 生成二维码
        if command -v qrencode >/dev/null 2>&1; then
            qrencode -t PNG -o "$batch_dir/$client_name.png" < "$CLIENT_DIR/$client_name.conf"
        fi
        
        echo "✓ 生成客户端: $client_name ($client_ip)"
    done
    
    # 重启WireGuard服务
    systemctl restart wg-quick@$WG_INTERFACE
    
    log_info "批量生成完成！"
    log_info "配置文件位置: $batch_dir"
    
    # 生成批量配置说明文件
    cat > "$batch_dir/README.txt" << EOF
WireGuard客户端配置文件
生成时间: $(date)
服务器: $SERVER_IP:$SERVER_PORT
客户端数量: $client_count

使用说明:
1. 将对应的.conf文件导入WireGuard客户端
2. 或扫描对应的.png二维码
3. 连接VPN

注意事项:
- 每个客户端配置只能在一台设备上使用
- 请妥善保管配置文件
- 如需删除客户端，请联系管理员
EOF
    
    echo ""
    echo "批量配置文件已保存到: $batch_dir"
}

# 导出现有客户端配置
export_existing_clients() {
    log_info "导出现有客户端配置..."
    
    if [[ ! -d $CLIENT_DIR ]] || [[ -z $(ls -A "$CLIENT_DIR" 2>/dev/null) ]]; then
        log_warn "没有找到现有客户端配置"
        return
    fi
    
    local export_dir="$EXPORT_DIR/export-$(date +%Y%m%d-%H%M%S)"
    mkdir -p "$export_dir"
    
    local count=0
    for config_file in "$CLIENT_DIR"/*.conf; do
        if [[ -f $config_file ]]; then
            local client_name=$(basename "$config_file" .conf)
            cp "$config_file" "$export_dir/"
            
            # 生成二维码
            if command -v qrencode >/dev/null 2>&1; then
                qrencode -t PNG -o "$export_dir/$client_name.png" < "$config_file"
            fi
            
            ((count++))
            echo "✓ 导出客户端: $client_name"
        fi
    done
    
    # 生成导出说明文件
    cat > "$export_dir/README.txt" << EOF
WireGuard客户端配置导出
导出时间: $(date)
服务器: $SERVER_IP:$SERVER_PORT
导出数量: $count

文件说明:
- .conf文件: 客户端配置文件
- .png文件: 配置二维码
- README.txt: 说明文件
EOF
    
    log_info "导出完成！共导出 $count 个客户端配置"
    log_info "导出位置: $export_dir"
}

# 生成客户端使用统计
generate_client_stats() {
    log_info "生成客户端使用统计..."
    
    local stats_file="$EXPORT_DIR/client-stats-$(date +%Y%m%d-%H%M%S).txt"
    
    cat > "$stats_file" << EOF
WireGuard客户端使用统计
生成时间: $(date)
服务器: $SERVER_IP:$SERVER_PORT

=== 服务状态 ===
$(systemctl status wg-quick@$WG_INTERFACE --no-pager -l)

=== 连接统计 ===
$(wg show)

=== 客户端列表 ===
EOF
    
    if [[ -d $CLIENT_DIR ]]; then
        echo "客户端名称                IP地址           状态" >> "$stats_file"
        echo "================================================" >> "$stats_file"
        
        for config_file in "$CLIENT_DIR"/*.conf; do
            if [[ -f $config_file ]]; then
                local client_name=$(basename "$config_file" .conf)
                local client_ip=$(grep "Address" "$config_file" | cut -d'=' -f2 | cut -d'/' -f1 | tr -d ' ')
                local status="离线"
                
                if wg show | grep -q "$client_ip"; then
                    status="在线"
                fi
                
                printf "%-25s %-15s %-10s\n" "$client_name" "$client_ip" "$status" >> "$stats_file"
            fi
        done
    else
        echo "暂无客户端配置" >> "$stats_file"
    fi
    
    cat >> "$stats_file" << EOF

=== 系统信息 ===
系统: $(uname -a)
内核: $(uname -r)
运行时间: $(uptime)
内存使用: $(free -h)
磁盘使用: $(df -h /)
EOF
    
    log_info "统计报告生成完成: $stats_file"
    
    # 显示简要统计
    echo ""
    echo "=== 简要统计 ==="
    local total_clients=$(find "$CLIENT_DIR" -name "*.conf" 2>/dev/null | wc -l)
    local online_clients=$(wg show | grep -c "peer:" 2>/dev/null || echo "0")
    
    echo "总客户端数: $total_clients"
    echo "在线客户端: $online_clients"
    echo "离线客户端: $((total_clients - online_clients))"
}

# 清理过期配置
cleanup_expired_configs() {
    log_info "清理过期配置..."
    
    read -p "请输入要保留的天数 (默认: 30): " keep_days
    keep_days=${keep_days:-30}
    
    if [[ ! $keep_days =~ ^[0-9]+$ ]]; then
        log_error "请输入有效的天数"
        return 1
    fi
    
    local cleanup_count=0
    
    # 清理导出目录中的旧文件
    if [[ -d $EXPORT_DIR ]]; then
        find "$EXPORT_DIR" -type f -mtime +$keep_days -delete
        find "$EXPORT_DIR" -type d -empty -delete
        cleanup_count=$(find "$EXPORT_DIR" -type f -mtime +$keep_days 2>/dev/null | wc -l)
    fi
    
    log_info "清理完成，删除了 $cleanup_count 个过期文件"
}

# 显示菜单
show_menu() {
    clear
    echo -e "${CYAN}"
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║                WireGuard客户端配置管理器                      ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    echo ""
    echo "1. 批量生成客户端配置"
    echo "2. 导出现有客户端配置"
    echo "3. 生成客户端使用统计"
    echo "4. 清理过期配置文件"
    echo "0. 退出"
    echo ""
}

# 主函数
main() {
    check_root
    check_wireguard_installed
    get_server_info
    
    while true; do
        show_menu
        read -p "请选择操作 (0-4): " choice
        
        case $choice in
            1)
                batch_generate_clients
                read -p "按回车键继续..."
                ;;
            2)
                export_existing_clients
                read -p "按回车键继续..."
                ;;
            3)
                generate_client_stats
                read -p "按回车键继续..."
                ;;
            4)
                cleanup_expired_configs
                read -p "按回车键继续..."
                ;;
            0)
                log_info "退出客户端配置管理器"
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
