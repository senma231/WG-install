#!/bin/bash

# WireGuard端口池配置生成器
# 用于生成大量可用端口池

# 生成端口池配置
generate_port_pool() {
    local pool_size=${1:-100}
    local start_port=${2:-51820}
    
    echo "# 自动生成的端口池配置 (共 $pool_size 个端口)"
    echo "AVAILABLE_PORTS=("
    
    # WireGuard标准端口范围
    echo "    # WireGuard标准端口范围"
    for ((i=0; i<30; i++)); do
        local port=$((start_port + i))
        printf "    %d" $port
        if [[ $i -lt 29 ]]; then
            echo ""
        else
            echo ""
        fi
    done
    
    # 高位端口范围1
    echo "    # 高位端口范围1 (52000-52099)"
    for ((i=0; i<30; i++)); do
        local port=$((52000 + i))
        printf "    %d" $port
        if [[ $i -lt 29 ]]; then
            echo ""
        else
            echo ""
        fi
    done
    
    # 高位端口范围2
    echo "    # 高位端口范围2 (53000-53099)"
    for ((i=0; i<30; i++)); do
        local port=$((53000 + i))
        printf "    %d" $port
        if [[ $i -lt 29 ]]; then
            echo ""
        else
            echo ""
        fi
    done
    
    # 非标准端口
    echo "    # 非标准端口"
    local nonstandard_ports=(2408 4096 8080 9999 10080 12345 23456 34567 45678 54321)
    for ((i=0; i<${#nonstandard_ports[@]}; i++)); do
        printf "    %d" ${nonstandard_ports[i]}
        if [[ $i -lt $((${#nonstandard_ports[@]} - 1)) ]]; then
            echo ""
        else
            echo ""
        fi
    done
    
    echo ")"
}

# 生成智能端口选择函数
generate_smart_port_selector() {
    cat << 'EOF'

# 智能端口选择算法
smart_port_selection() {
    local current_port=$1
    local preferred_ranges=(
        "51820:51849"  # WireGuard标准范围
        "52000:52099"  # 高位端口范围1
        "53000:53099"  # 高位端口范围2
        "54000:54099"  # 高位端口范围3
    )
    
    # 按优先级选择端口
    for range in "${preferred_ranges[@]}"; do
        local start_port=$(echo $range | cut -d':' -f1)
        local end_port=$(echo $range | cut -d':' -f2)
        
        for ((port=start_port; port<=end_port; port++)); do
            # 跳过当前端口
            if [[ $port == $current_port ]]; then
                continue
            fi
            
            # 检查端口是否被占用
            if ! ss -tulpn | grep -q ":$port "; then
                echo $port
                return 0
            fi
        done
    done
    
    # 如果所有预设端口都被占用，生成随机端口
    local random_port
    for ((i=0; i<50; i++)); do
        random_port=$((RANDOM % 10000 + 50000))
        if ! ss -tulpn | grep -q ":$random_port "; then
            echo $random_port
            return 0
        fi
    done
    
    return 1
}

# 端口健康检查
port_health_check() {
    local port=$1
    local score=0
    
    # 检查端口监听 (30分)
    if ss -ulpn | grep -q ":$port "; then
        score=$((score + 30))
    fi
    
    # 检查防火墙规则 (20分)
    if iptables -L INPUT | grep -q "$port"; then
        score=$((score + 20))
    fi
    
    # 检查外部连通性 (30分)
    local connectivity_score=0
    local test_hosts=("8.8.8.8" "1.1.1.1" "223.5.5.5")
    for host in "${test_hosts[@]}"; do
        if timeout 3 ping -c 1 "$host" >/dev/null 2>&1; then
            connectivity_score=$((connectivity_score + 10))
        fi
    done
    score=$((score + connectivity_score))
    
    # 检查WireGuard连接 (20分)
    if command -v wg >/dev/null 2>&1; then
        local handshake_count=$(wg show wg0 | grep -c "latest handshake" 2>/dev/null || echo "0")
        if [[ $handshake_count -gt 0 ]]; then
            score=$((score + 20))
        fi
    fi
    
    echo $score
}
EOF
}

# 主函数
main() {
    case "${1:-}" in
        "generate")
            local pool_size=${2:-100}
            generate_port_pool $pool_size
            ;;
        "smart")
            generate_smart_port_selector
            ;;
        "full")
            generate_port_pool 100
            generate_smart_port_selector
            ;;
        *)
            echo "用法: $0 {generate|smart|full} [端口数量]"
            echo ""
            echo "命令说明:"
            echo "  generate [数量] - 生成指定数量的端口池配置"
            echo "  smart          - 生成智能端口选择函数"
            echo "  full           - 生成完整配置 (端口池 + 智能选择)"
            echo ""
            echo "示例:"
            echo "  $0 generate 50    # 生成50个端口的配置"
            echo "  $0 smart          # 生成智能选择函数"
            echo "  $0 full           # 生成完整配置"
            ;;
    esac
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
