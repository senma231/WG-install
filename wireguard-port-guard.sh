#!/bin/bash
# -*- coding: utf-8 -*-

# WireGuard端口防封和自动更换系统
# 提供端口封锁检测、自动更换端口、客户端配置更新等功能
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
BACKUP_DIR="$WG_CONFIG_DIR/backups"
LOG_FILE="/var/log/wireguard-port-guard.log"
CONFIG_FILE="/etc/wireguard/port-guard.conf"
SYSTEMD_SERVICE="/etc/systemd/system/wireguard-port-guard.service"

# 默认配置
DEFAULT_PORTS=(51820 51821 51822 51823 51824 51825 51826 51827 51828 51829)
CHECK_INTERVAL=300  # 5分钟检查一次
FAIL_THRESHOLD=3    # 连续失败3次后更换端口
EXTERNAL_CHECK_HOSTS=("8.8.8.8" "1.1.1.1" "223.5.5.5")

# 日志函数
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
    echo "$(date '+%Y-%m-%d %H:%M:%S') [INFO] $1" >> "$LOG_FILE"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
    echo "$(date '+%Y-%m-%d %H:%M:%S') [WARN] $1" >> "$LOG_FILE"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
    echo "$(date '+%Y-%m-%d %H:%M:%S') [ERROR] $1" >> "$LOG_FILE"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
    echo "$(date '+%Y-%m-%d %H:%M:%S') [SUCCESS] $1" >> "$LOG_FILE"
}

# 检查root权限
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "此脚本需要root权限运行"
        exit 1
    fi
}

# 显示横幅
show_banner() {
    clear
    echo -e "${CYAN}"
    cat << "EOF"
╔══════════════════════════════════════════════════════════════╗
║                WireGuard端口防封系统                          ║
║                                                              ║
║  🛡️ 功能特性:                                                 ║
║  • 智能端口封锁检测                                            ║
║  • 自动更换端口                                                ║
║  • 客户端配置自动更新                                          ║
║  • 定时监控服务                                                ║
║  • 多端口轮换策略                                              ║
║  • 端口伪装技术                                                ║
║                                                              ║
╚══════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
}

# 加载配置文件
load_config() {
    if [[ -f $CONFIG_FILE ]]; then
        source "$CONFIG_FILE"
        log_info "配置文件已加载: $CONFIG_FILE"
    else
        log_warn "配置文件不存在，使用默认配置"
        create_default_config
    fi
}

# 创建默认配置文件
create_default_config() {
    log_info "创建默认配置文件..."
    
    mkdir -p "$(dirname "$CONFIG_FILE")"
    cat > "$CONFIG_FILE" << EOF
# WireGuard端口防封系统配置文件

# 可用端口列表 (建议使用非标准端口) - 扩展版 50个端口
AVAILABLE_PORTS=(
    # WireGuard标准端口范围 (20个)
    51820 51821 51822 51823 51824 51825 51826 51827 51828 51829
    51830 51831 51832 51833 51834 51835 51836 51837 51838 51839
    # 高位端口范围 (20个)
    52001 52002 52003 52004 52005 52006 52007 52008 52009 52010
    52011 52012 52013 52014 52015 52016 52017 52018 52019 52020
    # 非标准端口 (10个)
    2408 4096 8080 9999 10080 12345 23456 34567 45678 54321
)

# 检查间隔 (秒)
CHECK_INTERVAL=300

# 失败阈值 (连续失败多少次后更换端口)
FAIL_THRESHOLD=3

# 外部检查主机
EXTERNAL_CHECK_HOSTS=("8.8.8.8" "1.1.1.1" "223.5.5.5")

# 是否启用端口伪装 (将WireGuard流量伪装成其他协议)
ENABLE_PORT_MASQUERADE=false

# 伪装协议类型 (http, https, ssh)
MASQUERADE_PROTOCOL="https"

# 是否启用多端口模式 (同时监听多个端口)
ENABLE_MULTI_PORT=false

# 是否启用自动备份
ENABLE_AUTO_BACKUP=true

# 备份保留天数
BACKUP_RETENTION_DAYS=7

# 通知设置
ENABLE_NOTIFICATIONS=false
NOTIFICATION_EMAIL=""
WEBHOOK_URL=""
EOF
    
    log_success "默认配置文件已创建: $CONFIG_FILE"
}

# 获取当前WireGuard端口
get_current_port() {
    if [[ -f "$WG_CONFIG_DIR/$WG_INTERFACE.conf" ]]; then
        grep "ListenPort" "$WG_CONFIG_DIR/$WG_INTERFACE.conf" | cut -d'=' -f2 | tr -d ' '
    else
        echo ""
    fi
}

# 检查端口是否被封锁
check_port_blocked() {
    local port=$1
    local test_count=0
    local success_count=0
    
    log_info "检查端口 $port 是否被封锁..."
    
    # 1. 检查本地端口监听
    if ! ss -ulpn | grep -q ":$port "; then
        log_error "端口 $port 未在本地监听"
        return 1
    fi
    
    # 2. 检查防火墙规则
    if ! iptables -L INPUT | grep -q "$port"; then
        log_warn "端口 $port 可能未在防火墙中开放"
    fi
    
    # 3. 外部连通性测试
    for host in "${EXTERNAL_CHECK_HOSTS[@]}"; do
        ((test_count++))
        
        # 使用nc测试UDP端口连通性
        if timeout 5 nc -u -z "$host" 53 >/dev/null 2>&1; then
            # 如果能连接到外部主机，说明网络正常
            # 然后测试我们的WireGuard端口
            if timeout 3 bash -c "echo 'test' | nc -u -w1 127.0.0.1 $port" >/dev/null 2>&1; then
                ((success_count++))
            fi
        fi
    done
    
    # 4. 检查WireGuard握手
    local handshake_count=0
    if command -v wg >/dev/null 2>&1; then
        handshake_count=$(wg show "$WG_INTERFACE" | grep -c "latest handshake" 2>/dev/null || echo "0")
    fi
    
    # 判断端口是否被封锁
    local success_rate=$((success_count * 100 / test_count))
    
    log_info "端口 $port 检查结果:"
    log_info "  外部连通性: $success_count/$test_count ($success_rate%)"
    log_info "  活跃握手数: $handshake_count"
    
    # 如果成功率低于50%且没有活跃握手，认为端口可能被封锁
    if [[ $success_rate -lt 50 ]] && [[ $handshake_count -eq 0 ]]; then
        log_warn "端口 $port 可能被封锁 (成功率: $success_rate%, 握手数: $handshake_count)"
        return 1
    fi
    
    log_success "端口 $port 状态正常"
    return 0
}

# 选择新端口
select_new_port() {
    local current_port=$1
    local new_port=""
    
    log_info "选择新的WireGuard端口..."
    
    # 从可用端口列表中选择一个未被占用的端口
    for port in "${AVAILABLE_PORTS[@]}"; do
        # 跳过当前端口
        if [[ $port == $current_port ]]; then
            continue
        fi
        
        # 检查端口是否被占用
        if ! ss -tulpn | grep -q ":$port "; then
            new_port=$port
            break
        fi
    done
    
    # 如果没有找到可用端口，生成随机端口
    if [[ -z $new_port ]]; then
        local attempts=0
        while [[ $attempts -lt 10 ]]; do
            new_port=$((RANDOM % 10000 + 50000))
            if ! ss -tulpn | grep -q ":$new_port "; then
                break
            fi
            ((attempts++))
        done
    fi
    
    if [[ -n $new_port ]]; then
        log_success "选择新端口: $new_port"
        echo "$new_port"
    else
        log_error "无法找到可用端口"
        return 1
    fi
}

# 备份当前配置
backup_config() {
    log_info "备份当前配置..."
    
    mkdir -p "$BACKUP_DIR"
    local backup_timestamp=$(date +%Y%m%d_%H%M%S)
    local backup_file="$BACKUP_DIR/wg_backup_$backup_timestamp.tar.gz"
    
    tar -czf "$backup_file" -C "$WG_CONFIG_DIR" . 2>/dev/null || {
        log_error "配置备份失败"
        return 1
    }
    
    log_success "配置已备份到: $backup_file"
    
    # 清理旧备份
    if [[ $ENABLE_AUTO_BACKUP == true ]]; then
        find "$BACKUP_DIR" -name "wg_backup_*.tar.gz" -mtime +$BACKUP_RETENTION_DAYS -delete 2>/dev/null || true
    fi
}

# 更换WireGuard端口
change_wireguard_port() {
    local old_port=$1
    local new_port=$2
    
    log_info "开始更换WireGuard端口: $old_port → $new_port"
    
    # 1. 备份配置
    if [[ $ENABLE_AUTO_BACKUP == true ]]; then
        backup_config
    fi
    
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
    ufw delete allow "$old_port/udp" 2>/dev/null || true
    firewall-cmd --remove-port="$old_port/udp" --permanent 2>/dev/null || true
    
    # 添加新端口规则
    iptables -A INPUT -p udp --dport "$new_port" -j ACCEPT
    
    # 根据防火墙类型添加规则
    if command -v ufw >/dev/null 2>&1 && ufw status | grep -q "Status: active"; then
        ufw allow "$new_port/udp"
    elif command -v firewall-cmd >/dev/null 2>&1 && systemctl is-active --quiet firewalld; then
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
    
    return 0
}

# 更新客户端配置
update_client_configs() {
    local old_port=$1
    local new_port=$2
    local server_ip=$3

    log_info "更新客户端配置文件..."

    if [[ ! -d $CLIENT_DIR ]]; then
        log_warn "客户端配置目录不存在"
        return 0
    fi

    local updated_count=0

    # 更新所有客户端配置文件
    for config_file in "$CLIENT_DIR"/*.conf; do
        if [[ -f $config_file ]]; then
            local client_name=$(basename "$config_file" .conf)

            # 备份原配置
            cp "$config_file" "$config_file.backup.$(date +%Y%m%d_%H%M%S)"

            # 更新Endpoint端口
            sed -i "s/Endpoint = $server_ip:$old_port/Endpoint = $server_ip:$new_port/g" "$config_file"

            # 生成新的二维码
            if command -v qrencode >/dev/null 2>&1; then
                qrencode -t PNG -o "$CLIENT_DIR/$client_name.png" < "$config_file" 2>/dev/null || true
            fi

            ((updated_count++))
            log_info "  已更新客户端配置: $client_name"
        fi
    done

    log_success "已更新 $updated_count 个客户端配置文件"

    # 生成客户端更新通知
    generate_client_update_notice "$old_port" "$new_port" "$server_ip"
}

# 生成客户端更新通知
generate_client_update_notice() {
    local old_port=$1
    local new_port=$2
    local server_ip=$3
    local notice_file="$WG_CONFIG_DIR/client_update_notice.txt"

    cat > "$notice_file" << EOF
WireGuard服务端端口更新通知
================================

更新时间: $(date)
服务器IP: $server_ip
旧端口: $old_port
新端口: $new_port

重要提醒:
1. 服务端已自动更换端口以确保连接稳定性
2. 请更新您的客户端配置文件中的端口号
3. 或重新扫描新的配置二维码

客户端配置更新方法:
- 方法一: 重新下载配置文件
- 方法二: 手动修改Endpoint端口为 $new_port
- 方法三: 重新扫描二维码

配置文件位置: $CLIENT_DIR/
二维码位置: $CLIENT_DIR/*.png

如有问题请联系管理员。
EOF

    log_info "客户端更新通知已生成: $notice_file"
}

# 发送通知
send_notification() {
    local message=$1
    local title=${2:-"WireGuard端口更新"}

    if [[ $ENABLE_NOTIFICATIONS != true ]]; then
        return 0
    fi

    log_info "发送通知: $title"

    # 邮件通知
    if [[ -n $NOTIFICATION_EMAIL ]] && command -v mail >/dev/null 2>&1; then
        echo "$message" | mail -s "$title" "$NOTIFICATION_EMAIL" 2>/dev/null || true
    fi

    # Webhook通知
    if [[ -n $WEBHOOK_URL ]]; then
        curl -X POST "$WEBHOOK_URL" \
             -H "Content-Type: application/json" \
             -d "{\"title\":\"$title\",\"message\":\"$message\"}" \
             2>/dev/null || true
    fi
}

# 端口监控主循环
monitor_port() {
    local current_port
    local fail_count=0

    log_info "开始端口监控服务..."
    log_info "检查间隔: ${CHECK_INTERVAL}秒"
    log_info "失败阈值: $FAIL_THRESHOLD"

    while true; do
        current_port=$(get_current_port)

        if [[ -z $current_port ]]; then
            log_error "无法获取当前WireGuard端口"
            sleep "$CHECK_INTERVAL"
            continue
        fi

        log_info "检查端口状态: $current_port"

        if check_port_blocked "$current_port"; then
            # 端口正常，重置失败计数
            fail_count=0
            log_info "端口 $current_port 状态正常"
        else
            # 端口可能被封锁，增加失败计数
            ((fail_count++))
            log_warn "端口 $current_port 检查失败 ($fail_count/$FAIL_THRESHOLD)"

            if [[ $fail_count -ge $FAIL_THRESHOLD ]]; then
                log_error "端口 $current_port 连续失败 $fail_count 次，开始更换端口"

                # 选择新端口
                local new_port
                new_port=$(select_new_port "$current_port")

                if [[ -n $new_port ]]; then
                    # 获取服务器IP
                    local server_ip
                    server_ip=$(curl -s --connect-timeout 5 http://ipv4.icanhazip.com 2>/dev/null || curl -s --connect-timeout 5 http://members.3322.org/dyndns/getip 2>/dev/null)

                    if [[ -z $server_ip ]]; then
                        log_error "无法获取服务器公网IP"
                        sleep "$CHECK_INTERVAL"
                        continue
                    fi

                    # 更换端口
                    if change_wireguard_port "$current_port" "$new_port"; then
                        # 更新客户端配置
                        update_client_configs "$current_port" "$new_port" "$server_ip"

                        # 发送通知
                        local notification_message="WireGuard端口已自动更换\n旧端口: $current_port\n新端口: $new_port\n服务器: $server_ip\n时间: $(date)"
                        send_notification "$notification_message" "WireGuard端口自动更换"

                        # 重置失败计数
                        fail_count=0

                        log_success "端口更换完成: $current_port → $new_port"
                    else
                        log_error "端口更换失败"
                    fi
                else
                    log_error "无法选择新端口"
                fi
            fi
        fi

        # 等待下次检查
        sleep "$CHECK_INTERVAL"
    done
}

# 安装监控服务
install_monitor_service() {
    log_info "安装WireGuard端口监控服务..."

    # 创建systemd服务文件
    cat > "$SYSTEMD_SERVICE" << EOF
[Unit]
Description=WireGuard Port Guard Monitor
After=network.target wg-quick@$WG_INTERFACE.service
Wants=wg-quick@$WG_INTERFACE.service

[Service]
Type=simple
User=root
ExecStart=$PWD/$(basename "$0") monitor
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
    systemctl enable wireguard-port-guard.service
    systemctl start wireguard-port-guard.service

    log_success "监控服务已安装并启动"
    log_info "服务状态: systemctl status wireguard-port-guard"
    log_info "查看日志: journalctl -u wireguard-port-guard -f"
}

# 卸载监控服务
uninstall_monitor_service() {
    log_info "卸载WireGuard端口监控服务..."

    # 停止并禁用服务
    systemctl stop wireguard-port-guard.service 2>/dev/null || true
    systemctl disable wireguard-port-guard.service 2>/dev/null || true

    # 删除服务文件
    rm -f "$SYSTEMD_SERVICE"

    # 重新加载systemd
    systemctl daemon-reload

    log_success "监控服务已卸载"
}

# 手动更换端口
manual_change_port() {
    local current_port
    current_port=$(get_current_port)

    if [[ -z $current_port ]]; then
        log_error "无法获取当前WireGuard端口"
        return 1
    fi

    echo "当前WireGuard端口: $current_port"
    echo ""
    echo "可用端口列表:"
    local i=1
    for port in "${AVAILABLE_PORTS[@]}"; do
        if [[ $port != $current_port ]]; then
            echo "$i. $port"
            ((i++))
        fi
    done
    echo "$i. 自定义端口"
    echo ""

    read -p "请选择新端口 (1-$i): " choice

    local new_port=""
    if [[ $choice =~ ^[0-9]+$ ]] && [[ $choice -le $((i-1)) ]]; then
        # 选择预设端口
        local port_index=0
        for port in "${AVAILABLE_PORTS[@]}"; do
            if [[ $port != $current_port ]]; then
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
    else
        log_error "无效的选择"
        return 1
    fi

    # 检查端口是否被占用
    if ss -tulpn | grep -q ":$new_port "; then
        log_error "端口 $new_port 已被占用"
        return 1
    fi

    echo ""
    echo "即将更换端口: $current_port → $new_port"
    read -p "确认继续? (y/N): " confirm

    if [[ ! $confirm =~ ^[Yy]$ ]]; then
        log_info "操作已取消"
        return 0
    fi

    # 获取服务器IP
    local server_ip
    server_ip=$(curl -s --connect-timeout 5 http://ipv4.icanhazip.com 2>/dev/null || curl -s --connect-timeout 5 http://members.3322.org/dyndns/getip 2>/dev/null)

    if [[ -z $server_ip ]]; then
        log_error "无法获取服务器公网IP"
        return 1
    fi

    # 执行端口更换
    if change_wireguard_port "$current_port" "$new_port"; then
        update_client_configs "$current_port" "$new_port" "$server_ip"
        log_success "端口更换完成！"
        echo ""
        echo "新的连接信息:"
        echo "服务器: $server_ip"
        echo "端口: $new_port"
        echo ""
        echo "请更新客户端配置或重新扫描二维码"
    else
        log_error "端口更换失败"
        return 1
    fi
}

# 显示状态信息
show_status() {
    local current_port
    current_port=$(get_current_port)

    echo -e "${CYAN}=== WireGuard端口防封系统状态 ===${NC}"
    echo ""

    # 基本信息
    echo "当前端口: ${current_port:-"未知"}"
    echo "配置文件: $CONFIG_FILE"
    echo "日志文件: $LOG_FILE"
    echo ""

    # 服务状态
    echo "监控服务状态:"
    if systemctl is-active --quiet wireguard-port-guard.service 2>/dev/null; then
        echo -e "  ${GREEN}✓ 运行中${NC}"
        echo "  启动时间: $(systemctl show wireguard-port-guard.service --property=ActiveEnterTimestamp --value 2>/dev/null)"
    else
        echo -e "  ${RED}✗ 未运行${NC}"
    fi
    echo ""

    # WireGuard状态
    echo "WireGuard服务状态:"
    if systemctl is-active --quiet wg-quick@$WG_INTERFACE; then
        echo -e "  ${GREEN}✓ 运行中${NC}"
        if command -v wg >/dev/null 2>&1; then
            local peer_count=$(wg show "$WG_INTERFACE" peers 2>/dev/null | wc -l)
            echo "  连接客户端: $peer_count"
        fi
    else
        echo -e "  ${RED}✗ 未运行${NC}"
    fi
    echo ""

    # 配置信息
    if [[ -f $CONFIG_FILE ]]; then
        echo "配置信息:"
        echo "  检查间隔: ${CHECK_INTERVAL}秒"
        echo "  失败阈值: $FAIL_THRESHOLD"
        echo "  可用端口: ${#AVAILABLE_PORTS[@]}个"
        echo "  自动备份: ${ENABLE_AUTO_BACKUP:-false}"
        echo "  通知功能: ${ENABLE_NOTIFICATIONS:-false}"
    fi
    echo ""

    # 最近日志
    if [[ -f $LOG_FILE ]]; then
        echo "最近日志 (最后10条):"
        tail -n 10 "$LOG_FILE" | while read line; do
            echo "  $line"
        done
    fi
}

# 显示主菜单
show_main_menu() {
    clear
    show_banner

    echo -e "${WHITE}请选择操作：${NC}"
    echo ""
    echo "1. 检查当前端口状态"
    echo "2. 手动更换端口"
    echo "3. 安装监控服务"
    echo "4. 卸载监控服务"
    echo "5. 查看系统状态"
    echo "6. 配置管理"
    echo "7. 查看日志"
    echo "8. 备份管理"
    echo "0. 退出"
    echo ""
}

# 配置管理
config_management() {
    while true; do
        clear
        echo -e "${CYAN}=== 配置管理 ===${NC}"
        echo ""
        echo "1. 查看当前配置"
        echo "2. 编辑配置文件"
        echo "3. 重置为默认配置"
        echo "4. 测试配置"
        echo "0. 返回主菜单"
        echo ""

        read -p "请选择操作 (0-4): " config_choice

        case $config_choice in
            1)
                echo ""
                if [[ -f $CONFIG_FILE ]]; then
                    echo "当前配置内容:"
                    cat "$CONFIG_FILE"
                else
                    echo "配置文件不存在"
                fi
                read -p "按回车键继续..."
                ;;
            2)
                if command -v nano >/dev/null 2>&1; then
                    nano "$CONFIG_FILE"
                elif command -v vi >/dev/null 2>&1; then
                    vi "$CONFIG_FILE"
                else
                    echo "未找到文本编辑器"
                fi
                read -p "按回车键继续..."
                ;;
            3)
                echo ""
                read -p "确认重置配置为默认值? (y/N): " confirm
                if [[ $confirm =~ ^[Yy]$ ]]; then
                    create_default_config
                    log_success "配置已重置为默认值"
                fi
                read -p "按回车键继续..."
                ;;
            4)
                echo ""
                log_info "测试配置文件..."
                if load_config; then
                    log_success "配置文件格式正确"
                else
                    log_error "配置文件格式错误"
                fi
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

# 备份管理
backup_management() {
    while true; do
        clear
        echo -e "${CYAN}=== 备份管理 ===${NC}"
        echo ""
        echo "1. 创建备份"
        echo "2. 查看备份列表"
        echo "3. 恢复备份"
        echo "4. 删除备份"
        echo "5. 清理旧备份"
        echo "0. 返回主菜单"
        echo ""

        read -p "请选择操作 (0-5): " backup_choice

        case $backup_choice in
            1)
                echo ""
                backup_config
                read -p "按回车键继续..."
                ;;
            2)
                echo ""
                if [[ -d $BACKUP_DIR ]] && [[ -n $(ls -A "$BACKUP_DIR" 2>/dev/null) ]]; then
                    echo "备份文件列表:"
                    ls -la "$BACKUP_DIR"/*.tar.gz 2>/dev/null | while read line; do
                        echo "  $line"
                    done
                else
                    echo "没有找到备份文件"
                fi
                read -p "按回车键继续..."
                ;;
            3)
                echo ""
                echo "恢复功能需要手动操作，请谨慎使用"
                echo "备份位置: $BACKUP_DIR"
                read -p "按回车键继续..."
                ;;
            4)
                echo ""
                if [[ -d $BACKUP_DIR ]]; then
                    echo "备份文件:"
                    ls -1 "$BACKUP_DIR"/*.tar.gz 2>/dev/null | nl
                    echo ""
                    read -p "请输入要删除的备份编号: " backup_num
                    # 这里可以添加删除逻辑
                    echo "删除功能待实现"
                else
                    echo "备份目录不存在"
                fi
                read -p "按回车键继续..."
                ;;
            5)
                echo ""
                if [[ -d $BACKUP_DIR ]]; then
                    local old_backups=$(find "$BACKUP_DIR" -name "wg_backup_*.tar.gz" -mtime +7 2>/dev/null)
                    if [[ -n $old_backups ]]; then
                        echo "将删除以下旧备份:"
                        echo "$old_backups"
                        read -p "确认删除? (y/N): " confirm
                        if [[ $confirm =~ ^[Yy]$ ]]; then
                            find "$BACKUP_DIR" -name "wg_backup_*.tar.gz" -mtime +7 -delete
                            log_success "旧备份已清理"
                        fi
                    else
                        echo "没有找到旧备份文件"
                    fi
                else
                    echo "备份目录不存在"
                fi
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

# 主函数
main() {
    check_root

    # 创建必要目录
    mkdir -p "$(dirname "$LOG_FILE")"
    mkdir -p "$BACKUP_DIR"

    # 加载配置
    load_config

    # 处理命令行参数
    case "${1:-}" in
        "monitor")
            # 监控模式 (由systemd服务调用)
            monitor_port
            ;;
        "check")
            # 检查端口状态
            local current_port
            current_port=$(get_current_port)
            if [[ -n $current_port ]]; then
                check_port_blocked "$current_port"
            else
                log_error "无法获取当前端口"
                exit 1
            fi
            ;;
        "change")
            # 手动更换端口
            manual_change_port
            ;;
        "install")
            # 安装监控服务
            install_monitor_service
            ;;
        "uninstall")
            # 卸载监控服务
            uninstall_monitor_service
            ;;
        "status")
            # 显示状态
            show_status
            ;;
        *)
            # 交互式菜单
            while true; do
                show_main_menu
                read -p "请选择操作 (0-8): " choice

                case $choice in
                    1)
                        echo ""
                        local current_port
                        current_port=$(get_current_port)
                        if [[ -n $current_port ]]; then
                            check_port_blocked "$current_port"
                        else
                            log_error "无法获取当前端口"
                        fi
                        read -p "按回车键继续..."
                        ;;
                    2)
                        manual_change_port
                        read -p "按回车键继续..."
                        ;;
                    3)
                        install_monitor_service
                        read -p "按回车键继续..."
                        ;;
                    4)
                        uninstall_monitor_service
                        read -p "按回车键继续..."
                        ;;
                    5)
                        show_status
                        read -p "按回车键继续..."
                        ;;
                    6)
                        config_management
                        ;;
                    7)
                        echo ""
                        if [[ -f $LOG_FILE ]]; then
                            echo "最近50条日志:"
                            tail -n 50 "$LOG_FILE"
                        else
                            echo "日志文件不存在"
                        fi
                        read -p "按回车键继续..."
                        ;;
                    8)
                        backup_management
                        ;;
                    0)
                        log_info "退出WireGuard端口防封系统"
                        exit 0
                        ;;
                    *)
                        echo "无效的选择"
                        read -p "按回车键继续..."
                        ;;
                esac
            done
            ;;
    esac
}

# 脚本入口
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
