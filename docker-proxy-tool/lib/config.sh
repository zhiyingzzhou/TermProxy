#!/bin/bash

# Docker 代理配置脚本 - 配置模块
# 功能: 处理配置相关操作
# 作者: zhiyingzhou
# 版本: 2.0.0
# 日期: 2024-04-16

# 检查 Docker 守护进程配置文件是否存在
check_docker_config() {
    log_info "检查 Docker 配置..."
    
    # 检查配置目录是否存在
    if [ ! -d "$DOCKER_CONFIG_DIR" ]; then
        log_warn "Docker 配置目录不存在，尝试创建..."
        run_cmd mkdir -p "$DOCKER_CONFIG_DIR"
        
        if [ $? -ne 0 ]; then
            log_error "无法创建 Docker 配置目录: ${DOCKER_CONFIG_DIR}"
            read -p "是否继续? (y/n): " continue_op
            if [[ "$continue_op" =~ ^[Yy]$ ]]; then
                log_warn "继续执行，但可能会导致配置无法正确保存"
            else
                log_error "用户取消操作"
                exit 1
            fi
        fi
    fi
    
    # 检查配置文件是否存在
    if [ ! -f "$DOCKER_CONFIG_FILE" ]; then
        log_warn "Docker 配置文件不存在，创建默认配置..."
        local temp_config=$(mktemp)
        echo "{}" > "$temp_config"
        
        if [ $? -ne 0 ]; then
            log_error "无法创建临时配置文件"
            rm -f "$temp_config" 2>/dev/null
            return 1
        fi
        
        if ! update_config_file "$temp_config" "$DOCKER_CONFIG_FILE"; then
            log_error "无法创建 Docker 配置文件: ${DOCKER_CONFIG_FILE}"
            rm -f "$temp_config" 2>/dev/null
            read -p "是否继续? (y/n): " continue_op
            if [[ "$continue_op" =~ ^[Yy]$ ]]; then
                log_warn "继续执行，但可能会导致配置无法正确保存"
            else
                log_error "用户取消操作"
                exit 1
            fi
        fi
        
        rm -f "$temp_config" 2>/dev/null
    fi
    
    # 验证配置文件是否为有效的 JSON
    if ! run_jq empty "$DOCKER_CONFIG_FILE" 2>/dev/null; then
        log_error "Docker 配置文件不是有效的 JSON"
        echo "当前配置文件内容:"
        if [ "$(id -u)" -eq 0 ]; then
            cat "$DOCKER_CONFIG_FILE"
        elif [ "$USE_SUDO" = true ]; then
            sudo cat "$DOCKER_CONFIG_FILE"
        else
            cat "$DOCKER_CONFIG_FILE"
        fi
        
        # 备份无效配置
        local invalid_backup="${BACKUP_DIR}/daemon.json.invalid.$(date '+%Y%m%d_%H%M%S')"
        if [ "$(id -u)" -eq 0 ]; then
            cp "$DOCKER_CONFIG_FILE" "$invalid_backup"
        elif [ "$USE_SUDO" = true ]; then
            sudo cp "$DOCKER_CONFIG_FILE" "$invalid_backup"
        else
            cp "$DOCKER_CONFIG_FILE" "$invalid_backup"
        fi
        
        if [ $? -eq 0 ]; then
            log_info "已备份无效配置文件到: ${invalid_backup}"
        fi
        
        read -p "是否重置为空配置? (y/n): " reset_config
        if [[ "$reset_config" =~ ^[Yy]$ ]]; then
            local temp_config=$(mktemp)
            echo "{}" > "$temp_config"
            
            if update_config_file "$temp_config" "$DOCKER_CONFIG_FILE"; then
                log_success "配置文件已重置"
                rm -f "$temp_config" 2>/dev/null
            else
                log_error "重置配置文件失败"
                rm -f "$temp_config" 2>/dev/null
                exit 1
            fi
        else
            log_error "请手动修复配置文件后再运行此脚本"
            exit 1
        fi
    fi
    
    log_success "Docker 配置文件检查完成"
}

# 配置 registry-mirrors
configure_registry_mirrors() {
    clear
    print_header "配置 Docker Registry Mirrors"
    echo "请输入镜像地址，例如: https://mirror.example.com"
    read -p "镜像地址: " mirror_url
    
    if [ -z "$mirror_url" ]; then
        log_warn "未提供镜像地址，跳过配置"
        read -p "按回车键返回主菜单..." temp
        return
    fi
    
    if ! validate_url "$mirror_url"; then
        log_error "无效的 URL 格式"
        read -p "是否重新输入? (y/n): " retry
        if [[ "$retry" =~ ^[Yy]$ ]]; then
            configure_registry_mirrors
            return
        else
            return
        fi
    fi
    
    # 确保 URL 以 / 结尾
    [[ "$mirror_url" != */ ]] && mirror_url="${mirror_url}/"
    
    create_backup
    
    # 更新配置
    local temp_file=$(mktemp)
    
    # 确保配置文件存在
    if [ ! -f "$DOCKER_CONFIG_FILE" ]; then
        echo "{}" > "$temp_file"
        if ! update_config_file "$temp_file" "$DOCKER_CONFIG_FILE"; then
            log_error "无法创建配置文件"
            rm -f "$temp_file"
            read -p "按回车键返回主菜单..." temp
            return
        fi
    else
        # 读取当前配置
        if [ "$(id -u)" -eq 0 ]; then
            cat "$DOCKER_CONFIG_FILE" > "$temp_file" 2>/dev/null
        elif [ "$USE_SUDO" = true ]; then
            sudo cat "$DOCKER_CONFIG_FILE" > "$temp_file" 2>/dev/null
        else
            cat "$DOCKER_CONFIG_FILE" > "$temp_file" 2>/dev/null
        fi
        
        # 检查是否成功读取
        if [ ! -s "$temp_file" ]; then
            log_error "无法读取配置文件或配置文件为空"
            echo "{}" > "$temp_file"
        fi
    fi
    
    # 使用临时文件处理 jq 操作
    local temp_output=$(mktemp)
    local config_success=false
    
    if run_jq --arg mirror "$mirror_url" '.["registry-mirrors"] = [$mirror]' "$temp_file" > "$temp_output"; then
        if update_config_file "$temp_output" "$DOCKER_CONFIG_FILE"; then
            log_success "Registry mirrors 配置成功: $mirror_url"
            log_info "重启 Docker 后配置将生效"
            config_success=true
        else
            log_error "更新配置文件失败"
            # 尝试恢复备份
            if ! restore_backup; then
                log_warn "无法恢复原始配置"
            fi
        fi
    else
        log_error "生成配置失败"
    fi
    
    # 清理临时文件
    rm -f "$temp_file" "$temp_output" 2>/dev/null
    
    # 显示操作选项
    echo ""
    echo "操作完成！请选择："
    echo "1. 返回主菜单"
    
    if [ "$config_success" = true ]; then
        echo "2. 重启 Docker"
        echo "3. 显示当前配置"
        
        read -p "请选择 [1-3]: " next_action
        
        case $next_action in
            2)
                restart_docker
                ;;
            3)
                show_configuration
                ;;
            *)
                # 默认返回主菜单，不做任何操作
                ;;
        esac
    else
        read -p "按回车键返回主菜单..." temp
    fi
}

# 配置 HTTP/HTTPS 代理
configure_proxies() {
    clear
    print_header "配置 Docker HTTP/HTTPS 代理"
    echo "请输入代理地址（不含协议和端口），例如: proxy.example.com"
    read -p "代理地址: " proxy_host
    
    if [ -z "$proxy_host" ]; then
        log_warn "未提供代理地址，跳过配置"
        read -p "按回车键返回主菜单..." temp
        return
    fi
    
    read -p "代理端口: " proxy_port
    
    if ! validate_port "$proxy_port"; then
        log_error "无效的端口号"
        read -p "是否重新输入? (y/n): " retry
        if [[ "$retry" =~ ^[Yy]$ ]]; then
            configure_proxies
            return
        else
            return
        fi
    fi
    
    read -p "是否配置 HTTP 代理? (y/n): " configure_http
    read -p "是否配置 HTTPS 代理? (y/n): " configure_https
    
    # 如果两个选项都是否，直接返回
    if [[ ! "$configure_http" =~ ^[Yy]$ ]] && [[ ! "$configure_https" =~ ^[Yy]$ ]]; then
        log_warn "未选择任何代理类型，跳过配置"
        read -p "按回车键返回主菜单..." temp
        return
    fi
    
    create_backup
    
    # 更新配置
    local temp_file=$(mktemp)
    
    # 确保配置文件存在
    if [ ! -f "$DOCKER_CONFIG_FILE" ]; then
        echo "{}" > "$temp_file"
        if ! update_config_file "$temp_file" "$DOCKER_CONFIG_FILE"; then
            log_error "无法创建配置文件"
            rm -f "$temp_file"
            read -p "按回车键返回主菜单..." temp
            return
        fi
    else
        # 读取当前配置
        if [ "$(id -u)" -eq 0 ]; then
            cat "$DOCKER_CONFIG_FILE" > "$temp_file" 2>/dev/null
        elif [ "$USE_SUDO" = true ]; then
            sudo cat "$DOCKER_CONFIG_FILE" > "$temp_file" 2>/dev/null
        else
            cat "$DOCKER_CONFIG_FILE" > "$temp_file" 2>/dev/null
        fi
        
        # 检查是否成功读取
        if [ ! -s "$temp_file" ]; then
            log_error "无法读取配置文件或配置文件为空"
            echo "{}" > "$temp_file"
        fi
    fi
    
    local updated=false
    local temp_output=$(mktemp)
    
    if [[ "$configure_http" =~ ^[Yy]$ ]]; then
        http_proxy="http://${proxy_host}:${proxy_port}"
        
        cp "$temp_file" "$temp_output"
        if run_jq --arg proxy "$http_proxy" '.["proxies"]["http-proxy"] = $proxy' "$temp_file" > "$temp_output"; then
            cp "$temp_output" "$temp_file"  # 更新临时文件以便下一步操作
            updated=true
            log_success "HTTP 代理配置成功: $http_proxy"
        else
            log_error "配置 HTTP 代理失败"
        fi
    fi
    
    if [[ "$configure_https" =~ ^[Yy]$ ]]; then
        https_proxy="http://${proxy_host}:${proxy_port}"
        
        cp "$temp_file" "$temp_output"
        if run_jq --arg proxy "$https_proxy" '.["proxies"]["https-proxy"] = $proxy' "$temp_file" > "$temp_output"; then
            cp "$temp_output" "$temp_file"  # 更新临时文件以便下一步操作
            updated=true
            log_success "HTTPS 代理配置成功: $https_proxy"
        else
            log_error "配置 HTTPS 代理失败"
        fi
    fi
    
    local config_success=false
    
    if [ "$updated" = true ]; then
        if ! update_config_file "$temp_file" "$DOCKER_CONFIG_FILE"; then
            log_error "更新配置文件失败"
            # 尝试恢复备份
            if ! restore_backup; then
                log_warn "无法恢复原始配置"
            fi
        else
            log_success "代理配置成功应用"
            log_info "重启 Docker 后配置将生效"
            config_success=true
        fi
    else
        log_warn "未进行任何更改"
    fi
    
    # 清理临时文件
    rm -f "$temp_file" "$temp_output" 2>/dev/null
    
    # 显示操作选项
    echo ""
    echo "操作完成！请选择："
    echo "1. 返回主菜单"
    
    if [ "$config_success" = true ]; then
        echo "2. 重启 Docker"
        echo "3. 显示当前配置"
        
        read -p "请选择 [1-3]: " next_action
        
        case $next_action in
            2)
                restart_docker
                ;;
            3)
                show_configuration
                ;;
            *)
                # 默认返回主菜单，不做任何操作
                ;;
        esac
    else
        read -p "按回车键返回主菜单..." temp
    fi
}

# 清除配置
clear_configuration() {
    clear
    print_header "清除 Docker 代理配置"
    
    # 检查配置文件是否存在
    if [ ! -f "$DOCKER_CONFIG_FILE" ]; then
        log_warn "配置文件不存在，无需清除"
        read -p "按回车键返回主菜单..." temp
        return 0  # 确保正常返回
    fi
    
    read -p "是否清除 registry-mirrors 配置? (y/n): " clear_mirrors
    read -p "是否清除 HTTP/HTTPS 代理配置? (y/n): " clear_proxies
    
    # 如果两个选项都是否，直接返回
    if [[ ! "$clear_mirrors" =~ ^[Yy]$ ]] && [[ ! "$clear_proxies" =~ ^[Yy]$ ]]; then
        log_warn "未选择任何配置项，跳过清除"
        read -p "按回车键返回主菜单..." temp
        return 0  # 确保正常返回
    fi
    
    # 尝试创建备份
    log_info "创建配置备份..."
    
    # 创建备份目录（如果不存在）
    if [ ! -d "$BACKUP_DIR" ]; then
        mkdir -p "$BACKUP_DIR" 2>/dev/null
    fi
    
    local backup_created=false
    local backup_file=""
    
    # 只有当配置文件存在时才创建备份
    if [ -f "$DOCKER_CONFIG_FILE" ]; then
        local timestamp=$(date '+%Y%m%d_%H%M%S')
        backup_file="${BACKUP_DIR}/daemon.json.${timestamp}"
        
        if [ "$(id -u)" -eq 0 ]; then
            cp -f "$DOCKER_CONFIG_FILE" "$backup_file" 2>/dev/null && backup_created=true
        elif [ "$USE_SUDO" = true ]; then
            sudo cp -f "$DOCKER_CONFIG_FILE" "$backup_file" 2>/dev/null && backup_created=true
        else
            cp -f "$DOCKER_CONFIG_FILE" "$backup_file" 2>/dev/null && backup_created=true
        fi
        
        if [ "$backup_created" = true ]; then
            log_success "配置文件已备份到: ${backup_file}"
            chmod 600 "$backup_file" 2>/dev/null
        else
            log_warn "无法创建备份，但将继续执行清除操作"
        fi
    fi
    
    # 读取当前配置
    local temp_file=$(mktemp)
    local current_config=""
    
    if [ "$(id -u)" -eq 0 ]; then
        cat "$DOCKER_CONFIG_FILE" > "$temp_file" 2>/dev/null
    elif [ "$USE_SUDO" = true ]; then
        sudo cat "$DOCKER_CONFIG_FILE" > "$temp_file" 2>/dev/null
    else
        cat "$DOCKER_CONFIG_FILE" > "$temp_file" 2>/dev/null
    fi
    
    # 检查文件是否为空
    if [ ! -s "$temp_file" ]; then
        echo "{}" > "$temp_file"
    fi
    
    # 检查文件是否为有效的 JSON
    if ! cat "$temp_file" | jq empty >/dev/null 2>&1; then
        log_error "配置文件不是有效的 JSON，将重置为空对象"
        echo "{}" > "$temp_file"
    fi
    
    # 准备清除配置
    local needs_update=false
    local temp_output=$(mktemp)
    
    # 清除 registry-mirrors 配置
    if [[ "$clear_mirrors" =~ ^[Yy]$ ]]; then
        log_info "正在清除 Registry Mirrors 配置..."
        
        # 检查是否存在 registry-mirrors 配置
        if grep -q "registry-mirrors" "$temp_file" 2>/dev/null; then
            cat "$temp_file" | jq 'del(.["registry-mirrors"])' > "$temp_output" 2>/dev/null
            
            if [ $? -eq 0 ] && [ -s "$temp_output" ]; then
                cp -f "$temp_output" "$temp_file"
                needs_update=true
                log_success "Registry Mirrors 配置已清除"
            else
                log_error "清除 Registry Mirrors 配置失败"
                echo "{}" > "$temp_output"
                cp -f "$temp_output" "$temp_file"
            fi
        else
            log_info "未找到 Registry Mirrors 配置，无需清除"
        fi
    fi
    
    # 清除代理配置
    if [[ "$clear_proxies" =~ ^[Yy]$ ]]; then
        log_info "正在清除 HTTP/HTTPS 代理配置..."
        
        # 检查是否存在代理配置
        if grep -q "proxies" "$temp_file" 2>/dev/null; then
            cat "$temp_file" | jq 'del(.["proxies"])' > "$temp_output" 2>/dev/null
            
            if [ $? -eq 0 ] && [ -s "$temp_output" ]; then
                cp -f "$temp_output" "$temp_file"
                needs_update=true
                log_success "HTTP/HTTPS 代理配置已清除"
            else
                log_error "清除 HTTP/HTTPS 代理配置失败"
                echo "{}" > "$temp_output"
                cp -f "$temp_output" "$temp_file"
            fi
        else
            log_info "未找到 HTTP/HTTPS 代理配置，无需清除"
        fi
    fi
    
    # 更新 Docker 配置文件
    local update_success=false
    
    if [ "$needs_update" = true ]; then
        log_info "正在更新 Docker 配置文件..."
        
        if [ "$(id -u)" -eq 0 ]; then
            cp -f "$temp_file" "$DOCKER_CONFIG_FILE" 2>/dev/null && update_success=true
        elif [ "$USE_SUDO" = true ]; then
            sudo cp -f "$temp_file" "$DOCKER_CONFIG_FILE" 2>/dev/null && update_success=true
        else
            cp -f "$temp_file" "$DOCKER_CONFIG_FILE" 2>/dev/null && update_success=true
        fi
        
        if [ "$update_success" = true ]; then
            log_success "Docker 配置已成功更新"
            log_info "重启 Docker 后配置将生效"
        else
            log_error "更新 Docker 配置文件失败"
            
            # 如果有备份，尝试恢复
            if [ "$backup_created" = true ] && [ -f "$backup_file" ]; then
                log_info "尝试恢复备份..."
                
                if [ "$(id -u)" -eq 0 ]; then
                    cp -f "$backup_file" "$DOCKER_CONFIG_FILE" 2>/dev/null
                elif [ "$USE_SUDO" = true ]; then
                    sudo cp -f "$backup_file" "$DOCKER_CONFIG_FILE" 2>/dev/null
                else
                    cp -f "$backup_file" "$DOCKER_CONFIG_FILE" 2>/dev/null
                fi
                
                if [ $? -eq 0 ]; then
                    log_success "已恢复备份"
                else
                    log_error "恢复备份失败"
                fi
            fi
        fi
    else
        log_info "无需更新 Docker 配置文件"
    fi
    
    # 清理临时文件
    rm -f "$temp_file" "$temp_output" 2>/dev/null
    
    # 显示操作选项
    echo ""
    echo "操作完成！请选择："
    echo "1. 返回主菜单"
    
    if [ "$update_success" = true ]; then
        echo "2. 重启 Docker"
        echo "3. 显示当前配置"
        
        local choice=""
        read -p "请选择 [1-3]: " choice
        
        case $choice in
            2)
                # 在当前函数内重启 Docker
                restart_docker_inline
                ;;
            3)
                # 在当前函数内显示配置
                show_configuration_inline
                ;;
            *)
                # 返回主菜单，不做操作
                ;;
        esac
    else
        read -p "按回车键返回主菜单..." temp
    fi
}

# 内联重启 Docker（不会中断流程）
restart_docker_inline() {
    clear
    print_header "重启 Docker 服务"
    
    read -p "是否现在重启 Docker 服务? (y/n): " restart_choice
    
    if [[ "$restart_choice" =~ ^[Yy]$ ]]; then
        log_info "正在重启 Docker 服务..."
        
        local restart_success=false
        
        if [ "$OS_TYPE" == "macos" ]; then
            log_info "在 macOS 上重启 Docker..."
            if pgrep -x "Docker" > /dev/null; then
                osascript -e 'quit app "Docker"' 2>/dev/null
                sleep 2
                open -a Docker
                restart_success=true
            else
                log_error "Docker 应用未运行"
            fi
        elif command -v systemctl &>/dev/null; then
            if [ "$(id -u)" -eq 0 ]; then
                systemctl restart docker 2>/dev/null && restart_success=true
            elif [ "$USE_SUDO" = true ]; then
                sudo systemctl restart docker 2>/dev/null && restart_success=true
            else
                systemctl restart docker 2>/dev/null && restart_success=true
            fi
        elif command -v service &>/dev/null; then
            if [ "$(id -u)" -eq 0 ]; then
                service docker restart 2>/dev/null && restart_success=true
            elif [ "$USE_SUDO" = true ]; then
                sudo service docker restart 2>/dev/null && restart_success=true
            else
                service docker restart 2>/dev/null && restart_success=true
            fi
        else
            log_error "无法重启 Docker 服务: 未找到 systemctl 或 service 命令"
            echo "请手动重启 Docker 服务"
        fi
        
        if [ "$restart_success" = true ]; then
            log_success "Docker 服务已重启，配置已生效"
        else
            log_error "重启 Docker 服务失败"
        fi
    else
        log_warn "取消重启 Docker 服务"
    fi
    
    read -p "按回车键返回主菜单..." temp
}

# 内联显示配置（不会中断流程）
show_configuration_inline() {
    clear
    print_header "当前 Docker 配置"
    
    if [ ! -f "$DOCKER_CONFIG_FILE" ]; then
        log_warn "Docker 配置文件不存在"
        read -p "按回车键返回主菜单..." temp
        return
    fi
    
    # 读取配置文件
    local config_content=""
    
    if [ "$(id -u)" -eq 0 ]; then
        config_content=$(cat "$DOCKER_CONFIG_FILE" 2>/dev/null | jq . 2>/dev/null)
    elif [ "$USE_SUDO" = true ]; then
        config_content=$(sudo cat "$DOCKER_CONFIG_FILE" 2>/dev/null | jq . 2>/dev/null)
    else
        config_content=$(cat "$DOCKER_CONFIG_FILE" 2>/dev/null | jq . 2>/dev/null)
    fi
    
    if [ -z "$config_content" ]; then
        config_content="{}"
    fi
    
    # 输出格式化的配置
    echo -e "${GREEN}${config_content}${NC}"
    
    # 检查 registry-mirrors 配置
    if [ "$(id -u)" -eq 0 ]; then
        if cat "$DOCKER_CONFIG_FILE" 2>/dev/null | jq -e '."registry-mirrors"' >/dev/null 2>&1; then
            echo -e "\n${BLUE}已配置的 Registry Mirrors:${NC}"
            cat "$DOCKER_CONFIG_FILE" 2>/dev/null | jq -r '."registry-mirrors"[]' 2>/dev/null
        else
            echo -e "\n${YELLOW}未配置 Registry Mirrors${NC}"
        fi
    elif [ "$USE_SUDO" = true ]; then
        if sudo cat "$DOCKER_CONFIG_FILE" 2>/dev/null | jq -e '."registry-mirrors"' >/dev/null 2>&1; then
            echo -e "\n${BLUE}已配置的 Registry Mirrors:${NC}"
            sudo cat "$DOCKER_CONFIG_FILE" 2>/dev/null | jq -r '."registry-mirrors"[]' 2>/dev/null
        else
            echo -e "\n${YELLOW}未配置 Registry Mirrors${NC}"
        fi
    else
        if cat "$DOCKER_CONFIG_FILE" 2>/dev/null | jq -e '."registry-mirrors"' >/dev/null 2>&1; then
            echo -e "\n${BLUE}已配置的 Registry Mirrors:${NC}"
            cat "$DOCKER_CONFIG_FILE" 2>/dev/null | jq -r '."registry-mirrors"[]' 2>/dev/null
        else
            echo -e "\n${YELLOW}未配置 Registry Mirrors${NC}"
        fi
    fi
    
    # 检查代理配置
    if [ "$(id -u)" -eq 0 ]; then
        if cat "$DOCKER_CONFIG_FILE" 2>/dev/null | jq -e '."proxies"' >/dev/null 2>&1; then
            echo -e "\n${BLUE}已配置的代理:${NC}"
            if cat "$DOCKER_CONFIG_FILE" 2>/dev/null | jq -e '."proxies"."http-proxy"' >/dev/null 2>&1; then
                echo -e "HTTP 代理: $(cat "$DOCKER_CONFIG_FILE" 2>/dev/null | jq -r '."proxies"."http-proxy"' 2>/dev/null)"
            fi
            if cat "$DOCKER_CONFIG_FILE" 2>/dev/null | jq -e '."proxies"."https-proxy"' >/dev/null 2>&1; then
                echo -e "HTTPS 代理: $(cat "$DOCKER_CONFIG_FILE" 2>/dev/null | jq -r '."proxies"."https-proxy"' 2>/dev/null)"
            fi
        else
            echo -e "\n${YELLOW}未配置 HTTP/HTTPS 代理${NC}"
        fi
    elif [ "$USE_SUDO" = true ]; then
        if sudo cat "$DOCKER_CONFIG_FILE" 2>/dev/null | jq -e '."proxies"' >/dev/null 2>&1; then
            echo -e "\n${BLUE}已配置的代理:${NC}"
            if sudo cat "$DOCKER_CONFIG_FILE" 2>/dev/null | jq -e '."proxies"."http-proxy"' >/dev/null 2>&1; then
                echo -e "HTTP 代理: $(sudo cat "$DOCKER_CONFIG_FILE" 2>/dev/null | jq -r '."proxies"."http-proxy"' 2>/dev/null)"
            fi
            if sudo cat "$DOCKER_CONFIG_FILE" 2>/dev/null | jq -e '."proxies"."https-proxy"' >/dev/null 2>&1; then
                echo -e "HTTPS 代理: $(sudo cat "$DOCKER_CONFIG_FILE" 2>/dev/null | jq -r '."proxies"."https-proxy"' 2>/dev/null)"
            fi
        else
            echo -e "\n${YELLOW}未配置 HTTP/HTTPS 代理${NC}"
        fi
    else
        if cat "$DOCKER_CONFIG_FILE" 2>/dev/null | jq -e '."proxies"' >/dev/null 2>&1; then
            echo -e "\n${BLUE}已配置的代理:${NC}"
            if cat "$DOCKER_CONFIG_FILE" 2>/dev/null | jq -e '."proxies"."http-proxy"' >/dev/null 2>&1; then
                echo -e "HTTP 代理: $(cat "$DOCKER_CONFIG_FILE" 2>/dev/null | jq -r '."proxies"."http-proxy"' 2>/dev/null)"
            fi
            if cat "$DOCKER_CONFIG_FILE" 2>/dev/null | jq -e '."proxies"."https-proxy"' >/dev/null 2>&1; then
                echo -e "HTTPS 代理: $(cat "$DOCKER_CONFIG_FILE" 2>/dev/null | jq -r '."proxies"."https-proxy"' 2>/dev/null)"
            fi
        else
            echo -e "\n${YELLOW}未配置 HTTP/HTTPS 代理${NC}"
        fi
    fi
    
    read -p "按回车键返回主菜单..." temp
}

# 显示当前配置
show_configuration() {
    # 调用通用显示函数
    show_config_and_return
    
    # 显示操作选项
    echo ""
    echo "请选择："
    echo "1. 返回主菜单"
    echo "2. 重启 Docker"
    
    read -p "请选择 [1-2]: " next_action
    
    case $next_action in
        2)
            restart_docker
            ;;
        *)
            # 默认返回主菜单，不做任何操作
            ;;
    esac
}

# 显示配置并返回主菜单（内部使用）
show_config_and_return() {
    clear
    print_header "当前 Docker 代理配置"
    
    if [ ! -f "$DOCKER_CONFIG_FILE" ]; then
        log_warn "配置文件不存在"
        read -p "按回车键返回主菜单..." temp
        return
    fi
    
    # 获取配置文件内容
    local config_content
    if [ "$(id -u)" -eq 0 ]; then
        config_content=$(cat "$DOCKER_CONFIG_FILE" | jq . 2>/dev/null)
    elif [ "$USE_SUDO" = true ]; then
        config_content=$(sudo cat "$DOCKER_CONFIG_FILE" | jq . 2>/dev/null)
    else
        config_content=$(cat "$DOCKER_CONFIG_FILE" | jq . 2>/dev/null)
    fi
    
    if [ -z "$config_content" ]; then
        log_error "无法读取或解析配置文件"
        config_content="{}"
    fi
    
    # 格式化输出 JSON 配置
    echo -e "${GREEN}${config_content}${NC}"
    
    # 检查是否有 registry-mirrors 配置
    if run_jq -e '."registry-mirrors"' "$DOCKER_CONFIG_FILE" &>/dev/null; then
        echo -e "\n${BLUE}已配置的 Registry Mirrors:${NC}"
        if [ "$(id -u)" -eq 0 ]; then
            jq -r '."registry-mirrors"[]' "$DOCKER_CONFIG_FILE" 2>/dev/null
        elif [ "$USE_SUDO" = true ]; then
            sudo jq -r '."registry-mirrors"[]' "$DOCKER_CONFIG_FILE" 2>/dev/null
        else
            jq -r '."registry-mirrors"[]' "$DOCKER_CONFIG_FILE" 2>/dev/null
        fi
    else
        echo -e "\n${YELLOW}未配置 Registry Mirrors${NC}"
    fi
    
    # 检查是否有代理配置
    if run_jq -e '."proxies"' "$DOCKER_CONFIG_FILE" &>/dev/null; then
        echo -e "\n${BLUE}已配置的代理:${NC}"
        if run_jq -e '."proxies"."http-proxy"' "$DOCKER_CONFIG_FILE" &>/dev/null; then
            if [ "$(id -u)" -eq 0 ]; then
                echo -e "HTTP 代理: $(jq -r '."proxies"."http-proxy"' "$DOCKER_CONFIG_FILE" 2>/dev/null)"
            elif [ "$USE_SUDO" = true ]; then
                echo -e "HTTP 代理: $(sudo jq -r '."proxies"."http-proxy"' "$DOCKER_CONFIG_FILE" 2>/dev/null)"
            else
                echo -e "HTTP 代理: $(jq -r '."proxies"."http-proxy"' "$DOCKER_CONFIG_FILE" 2>/dev/null)"
            fi
        fi
        if run_jq -e '."proxies"."https-proxy"' "$DOCKER_CONFIG_FILE" &>/dev/null; then
            if [ "$(id -u)" -eq 0 ]; then
                echo -e "HTTPS 代理: $(jq -r '."proxies"."https-proxy"' "$DOCKER_CONFIG_FILE" 2>/dev/null)"
            elif [ "$USE_SUDO" = true ]; then
                echo -e "HTTPS 代理: $(sudo jq -r '."proxies"."https-proxy"' "$DOCKER_CONFIG_FILE" 2>/dev/null)"
            else
                echo -e "HTTPS 代理: $(jq -r '."proxies"."https-proxy"' "$DOCKER_CONFIG_FILE" 2>/dev/null)"
            fi
        fi
    else
        echo -e "\n${YELLOW}未配置 HTTP/HTTPS 代理${NC}"
    fi
    
    read -p "按回车键返回主菜单..." temp
}

# 重启 Docker 服务
restart_docker() {
    clear
    print_header "重启 Docker 服务"
    read -p "是否现在重启 Docker 服务? (y/n): " restart
    
    local success=false
    
    if [[ "$restart" =~ ^[Yy]$ ]]; then
        log_info "重启 Docker 服务..."
        
        if [ "$OS_TYPE" == "macos" ]; then
            log_info "在 macOS 上重启 Docker..."
            if pgrep -x "Docker" > /dev/null; then
                osascript -e 'quit app "Docker"'
                sleep 2
                open -a Docker
                success=true
            else
                log_error "Docker 应用未运行"
            fi
        elif command -v systemctl &>/dev/null; then
            run_cmd systemctl restart docker && success=true
        elif command -v service &>/dev/null; then
            run_cmd service docker restart && success=true
        else
            log_error "无法重启 Docker 服务: 未找到 systemctl 或 service 命令"
            echo "请手动重启 Docker 服务"
        fi
        
        if [ "$success" = true ]; then
            log_success "Docker 服务已重启，配置已生效"
            
            # 尝试更新 socket 权限
            if [ "$(id -u)" -ne 0 ] && id -nG "$CURRENT_USER" | grep -qw "docker"; then
                if [ "$USE_SUDO" = true ]; then
                    log_info "应用临时 Docker socket 权限..."
                    if [ -S "$DOCKER_SOCKET" ]; then
                        run_cmd chmod 666 "$DOCKER_SOCKET"
                        if [ $? -eq 0 ]; then
                            log_success "已应用临时 Docker socket 权限"
                            log_warn "您现在可以无需 sudo 使用 Docker，直到下次 Docker 重启"
                            
                            # 再次测试 Docker 访问权限
                            if docker info &>/dev/null; then
                                log_success "现在可以无需 sudo 访问 Docker"
                                USE_SUDO=false
                            fi
                        fi
                    fi
                fi
            fi
        fi
    else
        log_warn "取消重启 Docker 服务"
    fi
    
    # 显示操作选项
    echo ""
    echo "请选择："
    echo "1. 返回主菜单"
    echo "2. 显示当前配置"
    
    read -p "请选择 [1-2]: " next_action
    
    case $next_action in
        2)
            # 使用函数调用而不是直接显示，保持代码的可跟踪性
            show_config_and_return
            ;;
        *)
            # 默认返回主菜单，不做任何操作
            ;;
    esac
}

# 验证 URL 格式
validate_url() {
    local url=$1
    local url_regex='^(https?|http)://[-A-Za-z0-9\+&@#/%?=~_|!:,.;]*[-A-Za-z0-9\+&@#/%=~_|]$'
    
    if [[ ! $url =~ $url_regex ]]; then
        return 1
    fi
    return 0
}

# 验证端口格式
validate_port() {
    local port=$1
    if [[ ! $port =~ ^[0-9]+$ ]] || [ "$port" -lt 1 ] || [ "$port" -gt 65535 ]; then
        return 1
    fi
    return 0
}

# 静默清除所有配置（无用户交互）
clear_configuration_silent() {
    log_info "静默清除所有Docker配置..."
    
    # 检查配置文件是否存在
    if [ ! -f "$DOCKER_CONFIG_FILE" ]; then
        log_warn "配置文件不存在，无需清除"
        return 0
    fi
    
    # 创建备份
    create_backup
    
    # 检查并显示当前配置
    log_info "当前配置文件内容:"
    if [ "$(id -u)" -eq 0 ]; then
        cat "$DOCKER_CONFIG_FILE" | jq . 2>/dev/null || cat "$DOCKER_CONFIG_FILE"
    elif [ "$USE_SUDO" = true ]; then
        sudo cat "$DOCKER_CONFIG_FILE" | jq . 2>/dev/null || sudo cat "$DOCKER_CONFIG_FILE"
    else
        cat "$DOCKER_CONFIG_FILE" | jq . 2>/dev/null || cat "$DOCKER_CONFIG_FILE"
    fi
    
    # 准备清除所有配置
    log_info "清除所有配置项..."
    
    # 直接写入空配置而不是使用临时文件
    echo "{}" > /tmp/empty_config.$$.json
    
    if [ ! -s "/tmp/empty_config.$$.json" ]; then
        log_error "创建空配置文件失败"
        rm -f "/tmp/empty_config.$$.json" 2>/dev/null
        return 1
    fi
    
    # 更新Docker配置文件
    local update_success=false
    
    if [ "$(id -u)" -eq 0 ]; then
        cp -f "/tmp/empty_config.$$.json" "$DOCKER_CONFIG_FILE" && update_success=true
    elif [ "$USE_SUDO" = true ]; then
        sudo cp -f "/tmp/empty_config.$$.json" "$DOCKER_CONFIG_FILE" && update_success=true
    else
        cp -f "/tmp/empty_config.$$.json" "$DOCKER_CONFIG_FILE" && update_success=true
    fi
    
    # 清理临时文件
    rm -f "/tmp/empty_config.$$.json" 2>/dev/null
    
    # 验证更新是否成功
    if [ "$update_success" = true ]; then
        log_success "所有配置已清除"
        
        # 验证配置文件内容
        log_info "更新后的配置文件内容:"
        if [ "$(id -u)" -eq 0 ]; then
            cat "$DOCKER_CONFIG_FILE" | jq . 2>/dev/null || cat "$DOCKER_CONFIG_FILE"
        elif [ "$USE_SUDO" = true ]; then
            sudo cat "$DOCKER_CONFIG_FILE" | jq . 2>/dev/null || sudo cat "$DOCKER_CONFIG_FILE"
        else
            cat "$DOCKER_CONFIG_FILE" | jq . 2>/dev/null || cat "$DOCKER_CONFIG_FILE"
        fi
        
        # 尝试重启Docker以应用更改
        log_info "正在重启Docker服务以应用更改..."
        local restart_success=false
        
        if [ "$OS_TYPE" == "macos" ]; then
            if pgrep -x "Docker" > /dev/null; then
                osascript -e 'quit app "Docker"' 2>/dev/null
                sleep 2
                open -a Docker
                restart_success=true
            else
                log_error "Docker 应用未运行"
            fi
        elif command -v systemctl &>/dev/null; then
            run_cmd systemctl restart docker && restart_success=true
        elif command -v service &>/dev/null; then
            run_cmd service docker restart && restart_success=true
        else
            log_error "无法重启 Docker 服务: 未找到 systemctl 或 service 命令"
        fi
        
        if [ "$restart_success" = true ]; then
            log_success "Docker 服务已重启，配置已生效"
        else
            log_warn "Docker 服务重启失败，请手动重启以应用更改"
        fi
        
        return 0
    else
        log_error "清除配置失败"
        # 尝试恢复备份
        restore_backup
        return 1
    fi
} 