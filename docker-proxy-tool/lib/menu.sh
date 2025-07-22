#!/bin/bash

# Docker 代理配置脚本 - 菜单模块
# 功能: 处理菜单显示和选择
# 作者: zhiyingzhou
# 版本: 2.0.0
# 日期: 2024-04-16

# 显示主菜单
show_main_menu() {
    while true; do
        clear
        print_header "Docker 代理配置工具 v${SCRIPT_VERSION}"
        
        echo "1. 配置 Registry Mirrors"
        echo "2. 配置 HTTP/HTTPS 代理"
        echo "3. 清除配置"
        echo "4. 显示当前配置"
        echo "5. 重启 Docker 服务"
        
        if [ "$USE_SUDO" = true ]; then
            echo "6. 立即获取 Docker 访问权限"
        fi
        
        echo "7. 查看系统信息"
        echo "8. 查看备份管理"
        echo "0. 退出"
        
        echo -e "\n${BLUE}当前状态:${NC}"
        echo "- 操作系统: ${OS_TYPE} ${OS_VERSION}"
        echo "- Docker 版本: ${DOCKER_VERSION}"
        echo "- 当前用户: ${CURRENT_USER}"
        echo "- 需要 sudo: $([ "$USE_SUDO" = true ] && echo "是" || echo "否")"
        echo "- 配置文件: ${DOCKER_CONFIG_FILE}"
        echo -e "${BLUE}==========================================${NC}"
        
        read -p "请选择操作 [0-8]: " choice
        
        case $choice in
            1)
                configure_registry_mirrors
                ;;
            2)
                configure_proxies
                ;;
            3)
                clear_configuration
                ;;
            4)
                show_configuration
                ;;
            5)
                restart_docker
                ;;
            6)
                if [ "$USE_SUDO" = true ]; then
                    clear
                    print_header "获取 Docker 访问权限"
                    get_immediate_access
                    read -p "按回车键返回主菜单..." temp
                else
                    log_error "无效的选择，当前用户已有 Docker 访问权限"
                    sleep 1
                fi
                ;;
            7)
                show_system_info
                ;;
            8)
                manage_backups
                ;;
            0)
                clear
                print_header "退出配置工具"
                read -p "是否在退出前清除所有Docker代理配置? (y/n): " clear_before_exit
                if [[ "$clear_before_exit" =~ ^[Yy]$ ]]; then
                    log_info "正在清除所有配置..."
                    # 自动选择清除所有配置项
                    clear_configuration_silent
                    log_success "配置已清除，感谢使用 Docker 代理配置工具!"
                    # 增加一个确认步骤，显示当前配置状态
                    echo ""
                    if [ -f "$DOCKER_CONFIG_FILE" ]; then
                        log_info "当前Docker配置文件内容:"
                        if [ "$(id -u)" -eq 0 ]; then
                            cat "$DOCKER_CONFIG_FILE" | jq . 2>/dev/null || cat "$DOCKER_CONFIG_FILE"
                        elif [ "$USE_SUDO" = true ]; then
                            sudo cat "$DOCKER_CONFIG_FILE" | jq . 2>/dev/null || sudo cat "$DOCKER_CONFIG_FILE"
                        else
                            cat "$DOCKER_CONFIG_FILE" | jq . 2>/dev/null || cat "$DOCKER_CONFIG_FILE"
                        fi
                    else
                        log_warn "Docker配置文件不存在"
                    fi
                    # 添加暂停等待用户确认
                    read -p "配置已清除，按回车键退出..." temp
                else
                    echo "感谢使用 Docker 代理配置工具!"
                    read -p "按回车键退出..." temp
                fi
                exit 0
                ;;
            *)
                log_error "无效的选择，请重试"
                sleep 1
                ;;
        esac
    done
}

# 显示系统信息
show_system_info() {
    clear
    print_header "系统信息"
    
    echo -e "${BLUE}操作系统信息:${NC}"
    echo "- 类型: ${OS_TYPE}"
    echo "- 版本: ${OS_VERSION}"
    
    echo -e "\n${BLUE}Docker 信息:${NC}"
    echo "- 版本: ${DOCKER_VERSION}"
    echo "- 配置目录: ${DOCKER_CONFIG_DIR}"
    echo "- 配置文件: ${DOCKER_CONFIG_FILE}"
    echo "- Socket 文件: ${DOCKER_SOCKET}"
    
    echo -e "\n${BLUE}用户信息:${NC}"
    echo "- 当前用户: ${CURRENT_USER}"
    echo "- 用户 ID: $(id -u)"
    echo "- 用户组: $(id -gn)"
    echo "- 所有组: $(id -Gn | tr ' ' ',')"
    echo "- 需要 sudo: $([ "$USE_SUDO" = true ] && echo "是" || echo "否")"
    
    echo -e "\n${BLUE}脚本信息:${NC}"
    echo "- 版本: ${SCRIPT_VERSION}"
    echo "- 配置目录: ${DATA_DIR}"
    echo "- 日志文件: ${LOG_FILE}"
    echo "- 备份目录: ${BACKUP_DIR}"
    
    # 检查 Docker 服务状态
    echo -e "\n${BLUE}Docker 服务状态:${NC}"
    if [ "$OS_TYPE" == "macos" ]; then
        if pgrep -x "Docker" > /dev/null; then
            echo -e "${GREEN}- Docker 应用运行中${NC}"
        else
            echo -e "${RED}- Docker 应用未运行${NC}"
        fi
    elif command -v systemctl &>/dev/null; then
        systemctl status docker | head -3
    elif command -v service &>/dev/null; then
        service docker status
    else
        echo "- 无法确定 Docker 服务状态"
    fi
    
    read -p "按回车键返回主菜单..." temp
}

# 管理备份
manage_backups() {
    clear
    print_header "备份管理"
    
    # 检查备份目录是否存在
    if [ ! -d "$BACKUP_DIR" ]; then
        log_warn "备份目录不存在: ${BACKUP_DIR}"
        read -p "是否创建备份目录? (y/n): " create_dir
        if [[ "$create_dir" =~ ^[Yy]$ ]]; then
            if mkdir -p "$BACKUP_DIR" 2>/dev/null; then
                log_success "已创建备份目录"
            else
                log_error "无法创建备份目录"
                read -p "按回车键返回主菜单..." temp
                return
            fi
        else
            read -p "按回车键返回主菜单..." temp
            return
        fi
    fi
    
    # 获取所有备份文件
    local backup_files=()
    if ls "${BACKUP_DIR}"/daemon.json.* &>/dev/null; then
        backup_files=($(ls -t "${BACKUP_DIR}"/daemon.json.* 2>/dev/null))
    fi
    
    local backup_count=${#backup_files[@]}
    
    if [ $backup_count -eq 0 ]; then
        log_warn "没有可用的备份文件"
        read -p "按回车键返回主菜单..." temp
        return
    fi
    
    echo "找到 ${backup_count} 个备份文件:"
    for i in "${!backup_files[@]}"; do
        local file="${backup_files[$i]}"
        local timestamp=$(basename "$file" | cut -d. -f2-)
        # 检查文件是否存在，可能已被删除
        if [ -f "$file" ]; then
            echo "$((i+1)). $(date -r "$file" '+%Y-%m-%d %H:%M:%S') ($timestamp)"
        else
            echo "$((i+1)). [文件已删除] ($timestamp)"
        fi
    done
    
    echo -e "\n选项:"
    echo "r. 恢复最新备份"
    echo "d. 删除所有备份"
    echo "c. 清理不存在的备份记录"
    echo "0. 返回主菜单"
    
    read -p "请选择操作 [0/r/d/c/1-${backup_count}]: " backup_choice
    
    case $backup_choice in
        r)
            if restore_backup; then
                log_success "已恢复最新备份"
            else
                log_error "恢复备份失败"
            fi
            ;;
        d)
            read -p "确定要删除所有备份? (y/n): " confirm
            if [[ "$confirm" =~ ^[Yy]$ ]]; then
                rm -f "${BACKUP_DIR}"/daemon.json.* 2>/dev/null
                if [ $? -eq 0 ]; then
                    log_success "所有备份已删除"
                else
                    log_error "删除备份失败"
                fi
            fi
            ;;
        c)
            # 清理不存在的备份记录
            local valid_count=0
            for file in "${backup_files[@]}"; do
                if [ -f "$file" ]; then
                    valid_count=$((valid_count+1))
                else
                    log_info "清理无效备份记录: $(basename "$file")"
                fi
            done
            log_success "清理完成，有效备份：${valid_count}个"
            ;;
        0)
            return
            ;;
        [1-9]*)
            if [ "$backup_choice" -gt 0 ] && [ "$backup_choice" -le "$backup_count" ]; then
                local selected_file="${backup_files[$((backup_choice-1))]}"
                
                # 检查所选文件是否存在
                if [ ! -f "$selected_file" ]; then
                    log_error "选择的备份文件不存在: $(basename "$selected_file")"
                else
                    if update_config_file "$selected_file" "$DOCKER_CONFIG_FILE"; then
                        log_success "已恢复备份: $(basename "$selected_file")"
                    else
                        log_error "恢复备份失败"
                    fi
                fi
            else
                log_error "无效的选择"
            fi
            ;;
        *)
            log_error "无效的选择"
            ;;
    esac
    
    read -p "按回车键返回主菜单..." temp
} 