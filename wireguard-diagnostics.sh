#!/bin/bash
# -*- coding: utf-8 -*-

# WireGuard系统诊断和故障排查工具
# 提供全面的系统检测和问题诊断功能
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
LOG_FILE="/var/log/wireguard-diagnostics.log"

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

# 系统基础检查
check_system_basics() {
    echo -e "${CYAN}=== 系统基础检查 ===${NC}"
    
    # 操作系统信息
    echo "操作系统: $(cat /etc/os-release | grep PRETTY_NAME | cut -d'"' -f2)"
    echo "内核版本: $(uname -r)"
    echo "系统架构: $(uname -m)"
    echo "运行时间: $(uptime -p)"
    
    # 内存和磁盘
    echo ""
    echo "内存使用情况:"
    free -h
    
    echo ""
    echo "磁盘使用情况:"
    df -h /
    
    # 负载情况
    echo ""
    echo "系统负载: $(uptime | awk -F'load average:' '{print $2}')"
    
    echo ""
}

# WireGuard服务检查
check_wireguard_service() {
    echo -e "${CYAN}=== WireGuard服务检查 ===${NC}"
    
    # 检查WireGuard是否安装
    if command -v wg >/dev/null 2>&1; then
        log_success "WireGuard工具已安装"
        echo "WireGuard版本: $(wg --version | head -n1)"
    else
        log_error "WireGuard工具未安装"
        return 1
    fi
    
    # 检查配置文件
    if [[ -f "$WG_CONFIG_DIR/$WG_INTERFACE.conf" ]]; then
        log_success "WireGuard配置文件存在"
        echo "配置文件: $WG_CONFIG_DIR/$WG_INTERFACE.conf"
        echo "配置文件权限: $(ls -la $WG_CONFIG_DIR/$WG_INTERFACE.conf | awk '{print $1}')"
    else
        log_error "WireGuard配置文件不存在"
        return 1
    fi
    
    # 检查服务状态
    if systemctl is-active --quiet wg-quick@$WG_INTERFACE; then
        log_success "WireGuard服务运行正常"
        echo "服务状态: $(systemctl is-active wg-quick@$WG_INTERFACE)"
        echo "启动时间: $(systemctl show wg-quick@$WG_INTERFACE --property=ActiveEnterTimestamp --value)"
    else
        log_error "WireGuard服务未运行"
        echo "服务状态: $(systemctl is-active wg-quick@$WG_INTERFACE)"
        echo "最近日志:"
        journalctl -u wg-quick@$WG_INTERFACE --no-pager -n 10
    fi
    
    # 检查服务是否开机自启
    if systemctl is-enabled --quiet wg-quick@$WG_INTERFACE; then
        log_success "WireGuard服务已设置开机自启"
    else
        log_warn "WireGuard服务未设置开机自启"
    fi
    
    echo ""
}

# 网络接口检查
check_network_interface() {
    echo -e "${CYAN}=== 网络接口检查 ===${NC}"
    
    # 检查WireGuard接口
    if ip link show "$WG_INTERFACE" >/dev/null 2>&1; then
        log_success "WireGuard网络接口存在"
        echo "接口状态:"
        ip addr show "$WG_INTERFACE"
        
        # 检查接口统计
        echo ""
        echo "接口统计:"
        ip -s link show "$WG_INTERFACE"
    else
        log_error "WireGuard网络接口不存在"
    fi
    
    # 检查路由表
    echo ""
    echo "相关路由:"
    ip route | grep -E "(wg0|10\.|172\.|192\.168\.)" || echo "未找到相关路由"
    
    echo ""
}

# 防火墙检查
check_firewall() {
    echo -e "${CYAN}=== 防火墙检查 ===${NC}"
    
    # 获取WireGuard端口
    local wg_port=$(grep "ListenPort" "$WG_CONFIG_DIR/$WG_INTERFACE.conf" 2>/dev/null | cut -d'=' -f2 | tr -d ' ')
    
    if [[ -n $wg_port ]]; then
        echo "WireGuard端口: $wg_port"
        
        # 检查端口监听
        if ss -ulpn | grep -q ":$wg_port"; then
            log_success "WireGuard端口正在监听"
            echo "端口监听详情:"
            ss -ulpn | grep ":$wg_port"
        else
            log_error "WireGuard端口未监听"
        fi
        
        # 检查不同防火墙
        if command -v ufw >/dev/null 2>&1 && ufw status | grep -q "Status: active"; then
            echo ""
            echo "UFW防火墙状态:"
            ufw status | grep -E "(Status|$wg_port)" || echo "未找到相关规则"
        elif command -v firewall-cmd >/dev/null 2>&1; then
            echo ""
            echo "firewalld防火墙状态:"
            firewall-cmd --list-ports | grep -q "$wg_port" && log_success "端口已开放" || log_warn "端口可能未开放"
        else
            echo ""
            echo "iptables规则:"
            iptables -L INPUT | grep -E "(ACCEPT|$wg_port)" | head -5
        fi
    else
        log_warn "无法获取WireGuard端口信息"
    fi
    
    echo ""
}

# 网络连通性检查
check_network_connectivity() {
    echo -e "${CYAN}=== 网络连通性检查 ===${NC}"
    
    local test_hosts=("8.8.8.8" "1.1.1.1" "223.5.5.5" "119.29.29.29")
    local success_count=0
    
    for host in "${test_hosts[@]}"; do
        if ping -c 3 -W 3 "$host" >/dev/null 2>&1; then
            log_success "$host 连通正常"
            ((success_count++))
        else
            log_error "$host 连通失败"
        fi
    done
    
    echo "连通性测试结果: $success_count/${#test_hosts[@]} 成功"
    
    # DNS解析测试
    echo ""
    echo "DNS解析测试:"
    local dns_hosts=("google.com" "baidu.com" "github.com")
    for host in "${dns_hosts[@]}"; do
        if nslookup "$host" >/dev/null 2>&1; then
            log_success "$host DNS解析正常"
        else
            log_warn "$host DNS解析失败"
        fi
    done
    
    echo ""
}

# 系统参数检查
check_system_parameters() {
    echo -e "${CYAN}=== 系统参数检查 ===${NC}"
    
    # IP转发检查
    local ip_forward=$(cat /proc/sys/net/ipv4/ip_forward)
    if [[ $ip_forward == "1" ]]; then
        log_success "IPv4转发已启用"
    else
        log_error "IPv4转发未启用"
    fi
    
    # BBR检查
    local congestion_control=$(sysctl net.ipv4.tcp_congestion_control 2>/dev/null | cut -d'=' -f2 | tr -d ' ')
    if [[ $congestion_control == "bbr" ]]; then
        log_success "BBR拥塞控制已启用"
    else
        log_warn "BBR拥塞控制未启用 (当前: $congestion_control)"
    fi
    
    # 队列调度检查
    local qdisc=$(sysctl net.core.default_qdisc 2>/dev/null | cut -d'=' -f2 | tr -d ' ')
    echo "队列调度算法: $qdisc"
    
    # 内存参数检查
    echo ""
    echo "网络缓冲区参数:"
    echo "rmem_max: $(sysctl net.core.rmem_max | cut -d'=' -f2 | tr -d ' ')"
    echo "wmem_max: $(sysctl net.core.wmem_max | cut -d'=' -f2 | tr -d ' ')"
    
    echo ""
}

# WireGuard连接状态检查
check_wireguard_connections() {
    echo -e "${CYAN}=== WireGuard连接状态 ===${NC}"
    
    if command -v wg >/dev/null 2>&1; then
        local wg_output=$(wg show 2>/dev/null)
        if [[ -n $wg_output ]]; then
            echo "$wg_output"
            
            # 统计连接数
            local peer_count=$(echo "$wg_output" | grep -c "peer:" 2>/dev/null || echo "0")
            echo ""
            echo "当前连接的客户端数量: $peer_count"
            
            # 检查最近握手时间
            if echo "$wg_output" | grep -q "latest handshake"; then
                echo ""
                echo "最近握手时间:"
                echo "$wg_output" | grep "latest handshake"
            fi
        else
            log_warn "没有活跃的WireGuard连接"
        fi
    else
        log_error "无法执行wg命令"
    fi
    
    echo ""
}

# 性能检查
check_performance() {
    echo -e "${CYAN}=== 性能检查 ===${NC}"
    
    # CPU使用率
    echo "CPU使用率:"
    top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1
    
    # 内存使用率
    echo ""
    echo "内存使用率:"
    free | grep Mem | awk '{printf "%.2f%%\n", $3/$2 * 100.0}'
    
    # 网络接口流量
    if ip link show "$WG_INTERFACE" >/dev/null 2>&1; then
        echo ""
        echo "WireGuard接口流量统计:"
        cat /proc/net/dev | grep "$WG_INTERFACE" | awk '{printf "RX: %s bytes, TX: %s bytes\n", $2, $10}'
    fi
    
    # 连接数统计
    echo ""
    echo "网络连接统计:"
    ss -s
    
    echo ""
}

# 生成诊断报告
generate_diagnostic_report() {
    local report_file="/tmp/wireguard-diagnostic-$(date +%Y%m%d-%H%M%S).txt"
    
    echo "生成诊断报告: $report_file"
    
    {
        echo "WireGuard系统诊断报告"
        echo "生成时间: $(date)"
        echo "========================================"
        echo ""
        
        check_system_basics
        check_wireguard_service
        check_network_interface
        check_firewall
        check_network_connectivity
        check_system_parameters
        check_wireguard_connections
        check_performance
        
        echo ""
        echo "========================================"
        echo "诊断完成"
        
    } > "$report_file"
    
    echo "诊断报告已保存到: $report_file"
    
    # 显示报告摘要
    echo ""
    echo -e "${WHITE}诊断摘要:${NC}"
    local errors=$(grep -c "ERROR" "$report_file" 2>/dev/null || echo "0")
    local warnings=$(grep -c "WARN" "$report_file" 2>/dev/null || echo "0")
    local successes=$(grep -c "SUCCESS" "$report_file" 2>/dev/null || echo "0")
    
    echo "成功项目: $successes"
    echo "警告项目: $warnings"
    echo "错误项目: $errors"
    
    if [[ $errors -gt 0 ]]; then
        echo -e "${RED}发现 $errors 个错误，建议检查相关配置${NC}"
    elif [[ $warnings -gt 0 ]]; then
        echo -e "${YELLOW}发现 $warnings 个警告，建议优化相关设置${NC}"
    else
        echo -e "${GREEN}系统运行正常！${NC}"
    fi
}

# 主函数
main() {
    check_root
    
    # 创建日志文件
    touch "$LOG_FILE"
    
    echo -e "${CYAN}"
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║                WireGuard系统诊断工具                         ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    echo ""
    
    log_info "开始系统诊断..."
    echo ""
    
    check_system_basics
    check_wireguard_service
    check_network_interface
    check_firewall
    check_network_connectivity
    check_system_parameters
    check_wireguard_connections
    check_performance
    
    echo ""
    read -p "是否生成详细诊断报告？(y/N): " generate_report
    if [[ $generate_report =~ ^[Yy]$ ]]; then
        generate_diagnostic_report
    fi
    
    echo ""
    log_info "诊断完成！"
}

# 脚本入口
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
