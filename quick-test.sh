#!/bin/bash

# 快速测试端口防封功能

echo "=== 快速功能测试 ==="

# 1. 检查port_guard_menu函数是否存在
if grep -q "^port_guard_menu() {" wireguard-all-in-one.sh; then
    echo "✓ port_guard_menu函数存在"
else
    echo "✗ port_guard_menu函数不存在"
    exit 1
fi

# 2. 检查主菜单选项9
if grep -q "9.*端口防封管理" wireguard-all-in-one.sh; then
    echo "✓ 主菜单包含端口防封选项"
else
    echo "✗ 主菜单缺少端口防封选项"
    exit 1
fi

# 3. 检查选项9的处理
if grep -A 2 "9)" wireguard-all-in-one.sh | grep -q "port_guard_menu"; then
    echo "✓ 选项9正确调用port_guard_menu"
else
    echo "✗ 选项9未正确调用port_guard_menu"
    exit 1
fi

# 4. 检查关键函数
key_functions=(
    "check_current_port_status"
    "manual_port_change"
    "execute_port_change"
    "enable_port_monitoring"
    "show_port_guard_status"
)

for func in "${key_functions[@]}"; do
    if grep -q "^$func() {" wireguard-all-in-one.sh; then
        echo "✓ $func函数存在"
    else
        echo "✗ $func函数不存在"
        exit 1
    fi
done

echo ""
echo "=== 所有检查通过 ==="
echo ""
echo "建议测试步骤:"
echo "1. sudo ./wireguard-all-in-one.sh"
echo "2. 选择选项 9"
echo "3. 应该会显示端口防封管理菜单"

# 5. 显示port_guard_menu函数的开头部分
echo ""
echo "=== port_guard_menu函数预览 ==="
grep -A 20 "^port_guard_menu() {" wireguard-all-in-one.sh
