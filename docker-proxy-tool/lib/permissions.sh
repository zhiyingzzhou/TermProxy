#!/bin/bash

# Docker 代理配置脚本 - 权限管理模块
# 功能: 处理权限相关操作
# 作者: zhiyingzhou
# 版本: 2.0.0
# 日期: 2024-04-16

# 检查当前用户是否有 Docker 执行权限
check_docker_permission() {
    log_info "检查 Docker 权限..."
    
    # 尝试不使用 sudo 执行 docker 命令
    if docker info &>/dev/null; then
        log_success "当前用户($CURRENT_USER)已有 Docker 执行权限"
        USE_SUDO=false
        return 0
    else
        log_warn "当前用户($CURRENT_USER)没有 Docker 执行权限"
        return 1
    fi
}

# 检查权限并提供用户选择
check_permissions() {
    log_info "检查用户权限..."
    
    # 首先检查当前用户是否已有 Docker 执行权限
    if check_docker_permission; then
        # 检查 Docker 配置目录权限
        if [ -w "$DOCKER_CONFIG_DIR" ]; then
            log_success "当前用户对 Docker 配置目录有写入权限"
            USE_SUDO=false
        else
            log_warn "当前用户没有 Docker 配置目录的写入权限，将使用 sudo"
            USE_SUDO=true
        fi
        return 0
    fi
    
    # 如果没有权限，检查是否为 root 用户
    if [ "$(id -u)" -eq 0 ]; then
        log_info "以 root 身份运行，具有所有权限"
        USE_SUDO=false
        return 0
    fi
    
    # 非 root 用户且没有 Docker 执行权限，提供选项
    clear
    print_header "需要 Docker 权限"
    echo "当前用户 ${CURRENT_USER} 没有 Docker 执行权限"
    echo "您有以下选择:"
    echo "1. 将当前用户添加到 docker 组并立即授予访问权限"
    echo "2. 使用 sudo 权限执行操作"
    echo "3. 退出并使用 sudo 重新运行此脚本"
    
    read -p "请选择 [1-3]: " perm_choice
    
    case $perm_choice in
        1)
            add_user_to_docker_group
            ;;
        2)
            USE_SUDO=true
            log_info "将使用 sudo 执行 Docker 命令"
            # 验证 sudo 权限
            if ! sudo -n true 2>/dev/null; then
                log_warn "需要输入 sudo 密码"
                if ! sudo true; then
                    log_error "sudo 权限验证失败"
                    exit 1
                fi
            fi
            log_success "sudo 权限验证成功"
            ;;
        3)
            log_info "请使用以下命令重新运行脚本:"
            echo "sudo $SCRIPT_DIR/docker-proxy.sh"
            exit 0
            ;;
        *)
            log_error "无效的选择"
            exit 1
            ;;
    esac
    
    # 无论以上选择，都确保检查配置目录的写入权限
    if [ ! -w "$DOCKER_CONFIG_DIR" ] && [ "$USE_SUDO" != true ]; then
        log_warn "当前用户没有 Docker 配置目录的写入权限，将使用 sudo"
        USE_SUDO=true
    fi
}

# 将用户添加到 docker 组
add_user_to_docker_group() {
    log_info "将用户添加到 docker 组..."
    
    if ! sudo grep -q "^docker:" /etc/group; then
        log_warn "docker 组不存在，尝试创建..."
        sudo groupadd docker || { log_error "创建 docker 组失败"; exit 1; }
    fi
    
    # 添加用户到 docker 组
    sudo usermod -aG docker $CURRENT_USER
    if [ $? -ne 0 ]; then
        log_error "将用户添加到 docker 组失败"
        read -p "是否使用 sudo 继续? (y/n): " use_sudo
        if [[ "$use_sudo" =~ ^[Yy]$ ]]; then
            USE_SUDO=true
        else
            log_error "无法继续配置"
            exit 1
        fi
    else
        log_success "已将用户 $CURRENT_USER 添加到 docker 组"
        
        # 提供立即访问权限的选项
        echo -e "${YELLOW}是否要立即获取 Docker 访问权限而无需注销登录? (y/n): ${NC}"
        read -p "(这将重启 Docker 服务并修改 docker.sock 权限): " immediate_access
        
        if [[ "$immediate_access" =~ ^[Yy]$ ]]; then
            get_immediate_access
        else
            echo -e "${YELLOW}请注销并重新登录以使 docker 组成员身份生效${NC}"
            read -p "是否使用 sudo 继续当前配置? (y/n): " continue_sudo
            if [[ "$continue_sudo" =~ ^[Yy]$ ]]; then
                USE_SUDO=true
            else
                echo "请注销并重新登录后再次运行此脚本"
                exit 0
            fi
        fi
    fi
}

# 立即获取 Docker 访问权限
get_immediate_access() {
    log_info "尝试获取立即访问权限..."
    
    if [ "$USE_SUDO" = false ]; then
        log_success "当前用户已有 Docker 执行权限，无需修改"
        return 0
    fi
    
    if [ "$(id -u)" -eq 0 ]; then
        log_warn "以 root 身份运行，无需修改 socket 权限"
        return 0
    fi
    
    # 重启 Docker 服务
    log_info "重启 Docker 服务..."
    local restart_success=false
    
    if [ "$OS_TYPE" == "macos" ]; then
        if pgrep -x "Docker" > /dev/null; then
            osascript -e 'quit app "Docker"'
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
        echo "请手动重启 Docker 服务"
    fi
    
    if [ "$restart_success" = true ]; then
        log_success "Docker 服务已重启"
        
        # 修改 Docker socket 权限
        if [ -S "$DOCKER_SOCKET" ]; then
            log_info "修改 Docker socket 权限..."
            run_cmd chmod 666 "$DOCKER_SOCKET"
            
            if [ $? -eq 0 ]; then
                log_success "已修改 Docker socket 权限"
                log_warn "此权限更改在 Docker 重启后将被重置"
                log_warn "重新登录后，您将通过 docker 组成员身份获得永久访问权限"
                
                # 再次测试 Docker 访问权限
                if docker info &>/dev/null; then
                    log_success "测试成功! 您现在可以无需 sudo 使用 Docker"
                    USE_SUDO=false
                    return 0
                else
                    log_error "测试失败，将继续使用 sudo"
                    USE_SUDO=true
                    return 1
                fi
            else
                log_error "修改 Docker socket 权限失败"
            fi
        else
            log_error "Docker socket 文件不存在: $DOCKER_SOCKET"
        fi
    fi
    
    USE_SUDO=true
    return 1
} 