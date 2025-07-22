#!/bin/bash

# Docker 代理配置脚本 - 主文件
# 功能: 配置 Docker registry-mirrors 和 HTTP/HTTPS 代理
# 作者: zhiyingzhou
# 版本: 2.0.0
# 日期: 2024-04-16

# 设置错误处理
set -euo pipefail
IFS=$'\n\t'

# 获取脚本目录的绝对路径
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 导入库文件
source "${SCRIPT_DIR}/lib/utils.sh"
source "${SCRIPT_DIR}/lib/config.sh"
source "${SCRIPT_DIR}/lib/permissions.sh"
source "${SCRIPT_DIR}/lib/menu.sh"

# 主函数
main() {
    clear
    print_header "Docker 代理配置工具 v${SCRIPT_VERSION}"
    
    # 初始化脚本环境
    init_script
    
    # 检查操作系统
    check_os
    
    # 检查 Docker 版本
    check_docker_version
    
    # 检查依赖
    check_dependencies
    
    # 初始化 USE_SUDO 变量默认为 false
    USE_SUDO=false
    
    # 检查权限
    check_permissions
    
    # 检查 Docker 配置
    check_docker_config
    
    # 显示主菜单
    show_main_menu
}

# 执行主函数
main "$@" 