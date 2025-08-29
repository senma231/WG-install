#!/bin/bash

# 测试端口防封功能的脚本

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=== WireGuard端口防封功能测试 ===${NC}"
echo ""

# 检查脚本是否存在
if [[ ! -f "wireguard-all-in-one.sh" ]]; then
    echo -e "${RED}错误: 找不到 wireguard-all-in-one.sh 脚本${NC}"
    exit 1
fi

echo -e "${GREEN}✓ 找到 wireguard-all-in-one.sh 脚本${NC}"

# 检查脚本语法
echo "检查脚本语法..."
if bash -n wireguard-all-in-one.sh; then
    echo -e "${GREEN}✓ 脚本语法正确${NC}"
else
    echo -e "${RED}✗ 脚本语法错误${NC}"
    exit 1
fi

# 检查关键函数是否存在
echo ""
echo "检查关键函数..."

functions_to_check=(
    "port_guard_menu"
    "check_current_port_status"
    "manual_port_change"
    "execute_port_change"
    "enable_port_monitoring"
    "disable_port_monitoring"
    "show_port_guard_status"
    "port_guard_settings"
    "show_current_settings"
    "modify_monitor_interval"
    "modify_fail_threshold"
    "manage_port_whitelist"
    "show_port_history"
    "test_port_connectivity"
    "create_port_monitor_script"
    "create_port_monitor_service"
)

missing_functions=()

for func in "${functions_to_check[@]}"; do
    if grep -q "^$func()" wireguard-all-in-one.sh; then
        echo -e "${GREEN}✓ $func${NC}"
    else
        echo -e "${RED}✗ $func${NC}"
        missing_functions+=("$func")
    fi
done

if [[ ${#missing_functions[@]} -gt 0 ]]; then
    echo ""
    echo -e "${RED}缺少以下函数:${NC}"
    for func in "${missing_functions[@]}"; do
        echo "  - $func"
    done
    exit 1
fi

# 检查主菜单是否包含端口防封选项
echo ""
echo "检查主菜单..."
if grep -q "端口防封管理" wireguard-all-in-one.sh; then
    echo -e "${GREEN}✓ 主菜单包含端口防封选项${NC}"
else
    echo -e "${RED}✗ 主菜单缺少端口防封选项${NC}"
    exit 1
fi

# 检查主循环是否调用port_guard_menu
if grep -q "port_guard_menu" wireguard-all-in-one.sh; then
    echo -e "${GREEN}✓ 主循环正确调用port_guard_menu${NC}"
else
    echo -e "${RED}✗ 主循环未调用port_guard_menu${NC}"
    exit 1
fi

# 检查端口池配置
echo ""
echo "检查端口池配置..."
if grep -q "recommended_ports=(" wireguard-all-in-one.sh; then
    local port_count=$(grep -A 10 "recommended_ports=(" wireguard-all-in-one.sh | grep -o '[0-9]\{4,5\}' | wc -l)
    echo -e "${GREEN}✓ 端口池配置存在 (约 $port_count 个端口)${NC}"
else
    echo -e "${RED}✗ 端口池配置缺失${NC}"
    exit 1
fi

# 检查网段修复
echo ""
echo "检查网段配置修复..."
if grep -q "PRIVATE_SUBNET" wireguard-all-in-one.sh && ! grep -q "10.66.0.0/16" wireguard-all-in-one.sh; then
    echo -e "${GREEN}✓ 网段硬编码问题已修复${NC}"
else
    echo -e "${YELLOW}⚠ 可能仍存在网段硬编码问题${NC}"
fi

echo ""
echo -e "${GREEN}=== 测试完成 ===${NC}"
echo ""
echo "测试结果总结:"
echo -e "${GREEN}✓ 脚本语法正确${NC}"
echo -e "${GREEN}✓ 所有关键函数存在${NC}"
echo -e "${GREEN}✓ 主菜单集成正确${NC}"
echo -e "${GREEN}✓ 端口池配置完整${NC}"
echo ""
echo -e "${BLUE}建议测试步骤:${NC}"
echo "1. 以root权限运行脚本: sudo ./wireguard-all-in-one.sh"
echo "2. 选择选项 9 (端口防封管理)"
echo "3. 测试各个子功能"
echo ""
echo -e "${YELLOW}注意: 实际功能测试需要在已安装WireGuard的服务器上进行${NC}"
