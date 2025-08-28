#!/bin/bash
# -*- coding: utf-8 -*-

# 中国网络环境WireGuard优化脚本
# 专门针对国内网络环境进行深度优化
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
NC='\033[0m'

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

# 优化系统内核参数
optimize_kernel_parameters() {
    log_info "优化系统内核参数..."
    
    # 备份原始配置
    cp /etc/sysctl.conf /etc/sysctl.conf.backup.$(date +%Y%m%d)
    
    # 添加优化参数
    cat >> /etc/sysctl.conf << 'EOF'

# ===== WireGuard 中国网络优化参数 =====
# TCP优化
net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbr
net.ipv4.tcp_fastopen = 3
net.ipv4.tcp_mtu_probing = 1
net.ipv4.tcp_base_mss = 1024
net.ipv4.tcp_mtu_probe_floor = 576
net.ipv4.tcp_min_tso_segs = 2
net.ipv4.tcp_autocorking = 0

# 缓冲区优化
net.core.rmem_max = 134217728
net.core.wmem_max = 134217728
net.core.rmem_default = 262144
net.core.wmem_default = 262144
net.ipv4.tcp_rmem = 8192 262144 134217728
net.ipv4.tcp_wmem = 8192 262144 134217728
net.ipv4.udp_rmem_min = 16384
net.ipv4.udp_wmem_min = 16384

# 网络队列优化
net.core.netdev_max_backlog = 30000
net.core.netdev_budget = 600
net.core.netdev_budget_usecs = 5000

# TCP连接优化
net.ipv4.tcp_max_syn_backlog = 8192
net.ipv4.tcp_max_tw_buckets = 2000000
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_fin_timeout = 10
net.ipv4.tcp_slow_start_after_idle = 0
net.ipv4.tcp_keepalive_time = 60
net.ipv4.tcp_keepalive_intvl = 10
net.ipv4.tcp_keepalive_probes = 6

# UDP优化
net.ipv4.udp_mem = 102400 873800 16777216
net.ipv4.udp_rmem_min = 16384
net.ipv4.udp_wmem_min = 16384

# 其他网络优化
net.ipv4.ip_local_port_range = 1024 65535
net.ipv4.tcp_window_scaling = 1
net.ipv4.tcp_timestamps = 1
net.ipv4.tcp_sack = 1
net.ipv4.tcp_fack = 1
net.ipv4.tcp_ecn = 1
net.ipv4.tcp_frto = 2
net.ipv4.tcp_rfc1337 = 1
net.ipv4.tcp_low_latency = 1

# 内存和文件句柄优化
fs.file-max = 1000000
fs.nr_open = 1000000
net.nf_conntrack_max = 1000000
net.netfilter.nf_conntrack_max = 1000000
net.netfilter.nf_conntrack_tcp_timeout_established = 1200
net.netfilter.nf_conntrack_tcp_timeout_close_wait = 60
net.netfilter.nf_conntrack_tcp_timeout_fin_wait = 120

# IPv6优化（如果启用）
net.ipv6.conf.all.forwarding = 1
net.ipv6.conf.default.forwarding = 1
EOF
    
    # 应用参数
    sysctl -p
    log_info "内核参数优化完成"
}

# 优化网络接口
optimize_network_interface() {
    log_info "优化网络接口参数..."
    
    # 获取主网络接口
    local main_interface=$(ip route | grep default | awk '{print $5}' | head -n1)
    
    if [[ -n $main_interface ]]; then
        log_info "主网络接口: $main_interface"
        
        # 设置网络接口队列长度
        ip link set dev "$main_interface" txqueuelen 10000
        
        # 启用网络接口的各种优化特性
        ethtool -K "$main_interface" rx on tx on sg on tso on ufo on gso on gro on lro on rxvlan on txvlan on ntuple on rxhash on 2>/dev/null || true
        
        # 设置网络接口缓冲区
        ethtool -G "$main_interface" rx 4096 tx 4096 2>/dev/null || true
        
        log_info "网络接口优化完成"
    else
        log_warn "无法检测到主网络接口"
    fi
}

# 优化DNS配置
optimize_dns() {
    log_info "优化DNS配置..."
    
    # 备份原始DNS配置
    cp /etc/resolv.conf /etc/resolv.conf.backup.$(date +%Y%m%d)
    
    # 配置国内优化DNS
    cat > /etc/resolv.conf << 'EOF'
# 国内优化DNS配置
nameserver 223.5.5.5
nameserver 119.29.29.29
nameserver 180.76.76.76
nameserver 114.114.114.114
options timeout:2
options attempts:2
options rotate
options single-request-reopen
EOF
    
    # 防止被覆盖
    chattr +i /etc/resolv.conf 2>/dev/null || true
    
    log_info "DNS配置优化完成"
}

# 优化系统限制
optimize_system_limits() {
    log_info "优化系统限制..."
    
    # 备份原始配置
    cp /etc/security/limits.conf /etc/security/limits.conf.backup.$(date +%Y%m%d)
    
    # 添加系统限制优化
    cat >> /etc/security/limits.conf << 'EOF'

# WireGuard 系统限制优化
* soft nofile 1000000
* hard nofile 1000000
* soft nproc 1000000
* hard nproc 1000000
* soft memlock unlimited
* hard memlock unlimited
root soft nofile 1000000
root hard nofile 1000000
root soft nproc 1000000
root hard nproc 1000000
EOF
    
    # 配置systemd限制
    mkdir -p /etc/systemd/system.conf.d
    cat > /etc/systemd/system.conf.d/limits.conf << 'EOF'
[Manager]
DefaultLimitNOFILE=1000000
DefaultLimitNPROC=1000000
DefaultLimitMEMLOCK=infinity
EOF
    
    # 配置systemd用户限制
    mkdir -p /etc/systemd/user.conf.d
    cat > /etc/systemd/user.conf.d/limits.conf << 'EOF'
[Manager]
DefaultLimitNOFILE=1000000
DefaultLimitNPROC=1000000
DefaultLimitMEMLOCK=infinity
EOF
    
    log_info "系统限制优化完成"
}

# 优化WireGuard特定参数
optimize_wireguard_specific() {
    log_info "优化WireGuard特定参数..."
    
    # 创建WireGuard优化配置
    cat > /etc/sysctl.d/99-wireguard-optimize.conf << 'EOF'
# WireGuard 专用优化参数
net.core.default_qdisc = fq_codel
net.ipv4.tcp_congestion_control = bbr

# UDP优化（WireGuard使用UDP）
net.core.rmem_max = 268435456
net.core.wmem_max = 268435456
net.core.rmem_default = 262144
net.core.wmem_default = 262144

# 减少网络延迟
net.ipv4.tcp_low_latency = 1
net.ipv4.tcp_frto = 2

# 优化网络队列
net.core.netdev_max_backlog = 50000
net.core.netdev_budget = 600

# 连接跟踪优化
net.netfilter.nf_conntrack_max = 2000000
net.netfilter.nf_conntrack_buckets = 500000
net.netfilter.nf_conntrack_tcp_timeout_established = 1200

# IPv4转发优化
net.ipv4.ip_forward = 1
net.ipv4.conf.all.forwarding = 1
net.ipv4.conf.default.forwarding = 1

# 路由优化
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv4.conf.all.secure_redirects = 0
net.ipv4.conf.default.secure_redirects = 0
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0
EOF
    
    # 应用配置
    sysctl -p /etc/sysctl.d/99-wireguard-optimize.conf
    
    log_info "WireGuard特定优化完成"
}

# 创建网络监控脚本
create_monitoring_script() {
    log_info "创建网络监控脚本..."
    
    cat > /usr/local/bin/wg-monitor.sh << 'EOF'
#!/bin/bash

# WireGuard网络监控脚本

WG_INTERFACE="wg0"
LOG_FILE="/var/log/wireguard-monitor.log"

# 记录日志
log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
}

# 检查WireGuard状态
check_wireguard() {
    if ! systemctl is-active --quiet wg-quick@$WG_INTERFACE; then
        log_message "WireGuard服务异常，尝试重启"
        systemctl restart wg-quick@$WG_INTERFACE
        if systemctl is-active --quiet wg-quick@$WG_INTERFACE; then
            log_message "WireGuard服务重启成功"
        else
            log_message "WireGuard服务重启失败"
        fi
    fi
}

# 检查网络连通性
check_connectivity() {
    if ! ping -c 1 -W 3 8.8.8.8 >/dev/null 2>&1; then
        log_message "网络连通性异常"
    fi
}

# 主监控循环
main() {
    check_wireguard
    check_connectivity
}

main "$@"
EOF
    
    chmod +x /usr/local/bin/wg-monitor.sh
    
    # 创建定时任务
    cat > /etc/cron.d/wireguard-monitor << 'EOF'
# WireGuard监控定时任务
*/5 * * * * root /usr/local/bin/wg-monitor.sh
EOF
    
    log_info "网络监控脚本创建完成"
}

# 主函数
main() {
    check_root
    
    echo "=== 中国网络环境WireGuard优化脚本 ==="
    echo ""
    
    log_info "开始优化..."
    
    optimize_kernel_parameters
    optimize_network_interface
    optimize_dns
    optimize_system_limits
    optimize_wireguard_specific
    create_monitoring_script
    
    echo ""
    log_info "优化完成！"
    echo ""
    echo "建议重启系统以确保所有优化生效："
    echo "reboot"
    echo ""
    echo "重启后可以使用以下命令验证优化效果："
    echo "sysctl net.ipv4.tcp_congestion_control"
    echo "sysctl net.core.default_qdisc"
    echo ""
}

# 脚本入口
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
