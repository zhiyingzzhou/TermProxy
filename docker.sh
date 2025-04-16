#!/bin/bash

# Docker 代理配置脚本
# 功能: 配置 Docker registry-mirrors 和 HTTP/HTTPS 代理
# 作者: zhiyingzhou
# 日期: 2025-04-16

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # 无颜色

# Docker 配置目录和文件
DOCKER_CONFIG_DIR="/etc/docker"
DOCKER_CONFIG_FILE="${DOCKER_CONFIG_DIR}/daemon.json"
DOCKER_SOCKET="/var/run/docker.sock"
CURRENT_USER=$(whoami)

# 使用变量标记是否需要使用 sudo
USE_SUDO=false

# 检查当前用户是否有 Docker 执行权限
check_docker_permission() {
    # 尝试不使用 sudo 执行 docker 命令
    if docker info &>/dev/null; then
        echo -e "${GREEN}当前用户($CURRENT_USER)已有 Docker 执行权限${NC}"
        USE_SUDO=false
        return 0
    else
        echo -e "${YELLOW}当前用户($CURRENT_USER)没有 Docker 执行权限${NC}"
        return 1
    fi
}

# 检查权限并提供用户选择
check_permissions() {
    # 首先检查当前用户是否已有 Docker 执行权限
    if check_docker_permission; then
        return 0
    fi
    
    # 如果没有权限，检查是否为 root 用户
    if [ "$(id -u)" -eq 0 ]; then
        return 0
    fi
    
    # 非 root 用户且没有 Docker 执行权限，提供选项
    echo -e "您有以下选择:"
    echo "1. 将当前用户(${CURRENT_USER})添加到 docker 组并立即授予访问权限"
    echo "2. 使用 sudo 重新运行此脚本"
    echo "3. 继续但使用 sudo 执行 Docker 命令"
    read -p "请选择 [1-3]: " perm_choice
    
    case $perm_choice in
        1)
            echo -e "${YELLOW}将尝试将用户添加到 docker 组并立即授予访问权限...${NC}"
            # 使用 sudo 添加用户到 docker 组
            if ! sudo grep -q "^docker:" /etc/group; then
                echo -e "${YELLOW}docker 组不存在，尝试创建...${NC}"
                sudo groupadd docker || { echo -e "${RED}创建 docker 组失败${NC}"; exit 1; }
            fi
            
            # 添加用户到 docker 组
            sudo usermod -aG docker $CURRENT_USER
            if [ $? -ne 0 ]; then
                echo -e "${RED}将用户添加到 docker 组失败${NC}"
                read -p "是否使用 sudo 继续? (y/n): " use_sudo
                if [[ "$use_sudo" =~ ^[Yy]$ ]]; then
                    USE_SUDO=true
                else
                    echo -e "${RED}无法继续配置${NC}"
                    exit 1
                fi
            else
                echo -e "${GREEN}已将用户 $CURRENT_USER 添加到 docker 组${NC}"
                
                # 提供立即访问权限的选项
                echo -e "${YELLOW}是否要立即获取 Docker 访问权限而无需注销登录? (y/n): ${NC}"
                read -p "(这将重启 Docker 服务并修改 docker.sock 权限): " immediate_access
                
                if [[ "$immediate_access" =~ ^[Yy]$ ]]; then
                    # 重启 Docker 服务
                    echo -e "${BLUE}重启 Docker 服务...${NC}"
                    if command -v systemctl &>/dev/null; then
                        sudo systemctl restart docker
                    elif command -v service &>/dev/null; then
                        sudo service docker restart
                    else
                        echo -e "${RED}无法重启 Docker 服务: 未找到 systemctl 或 service 命令${NC}"
                        echo "请手动重启 Docker 服务"
                    fi
                    
                    # 检查 Docker socket 文件是否存在
                    if [ -S "$DOCKER_SOCKET" ]; then
                        echo -e "${BLUE}临时修改 Docker socket 权限...${NC}"
                        # 修改 Docker socket 权限
                        sudo chmod a+rw "$DOCKER_SOCKET"
                        
                        if [ $? -eq 0 ]; then
                            echo -e "${GREEN}已修改 Docker socket 权限，您现在可以无需 sudo 使用 Docker${NC}"
                            echo -e "${YELLOW}注意: 此权限更改在 Docker 重启后将被重置${NC}"
                            echo -e "${YELLOW}重新登录后，您将通过 docker 组成员身份获得永久访问权限${NC}"
                        else
                            echo -e "${RED}修改 Docker socket 权限失败${NC}"
                        fi
                    else
                        echo -e "${RED}Docker socket 文件不存在: $DOCKER_SOCKET${NC}"
                    fi
                    
                    # 再次测试 Docker 访问权限
                    echo -e "${BLUE}测试 Docker 访问权限...${NC}"
                    if docker info &>/dev/null; then
                        echo -e "${GREEN}测试成功! 您现在可以无需 sudo 使用 Docker${NC}"
                        # 无需使用 sudo 继续操作
                        USE_SUDO=false
                    else
                        echo -e "${RED}测试失败，将继续使用 sudo 完成配置${NC}"
                        USE_SUDO=true
                    fi
                else
                    echo -e "${YELLOW}请注销并重新登录以使 docker 组成员身份生效${NC}"
                    read -p "是否使用 sudo 继续当前配置? (y/n): " continue_sudo
                    if [[ "$continue_sudo" =~ ^[Yy]$ ]]; then
                        echo "将使用 sudo 执行剩余操作"
                        USE_SUDO=true
                    else
                        echo "请注销并重新登录后再次运行此脚本"
                        exit 0
                    fi
                fi
            fi
            ;;
        2)
            echo "请使用以下命令重新运行脚本:"
            echo "sudo $0"
            exit 0
            ;;
        3)
            echo -e "${YELLOW}将在需要时使用 sudo 执行 Docker 命令${NC}"
            USE_SUDO=true
            ;;
        *)
            echo -e "${RED}无效的选择${NC}"
            exit 1
            ;;
    esac
}

# 执行命令，根据需要添加 sudo
run_cmd() {
    if [ "$(id -u)" -eq 0 ] || [ "$USE_SUDO" = false ]; then
        eval "$@"
    else
        sudo $@
    fi
}

# 检查 Docker 是否已安装
check_docker() {
    if ! command -v docker &> /dev/null; then
        echo -e "${RED}错误: Docker 未安装${NC}"
        echo "请先安装 Docker，然后再运行此脚本"
        exit 1
    fi
}

# 检查 Docker 服务是否运行
check_docker_running() {
    # 根据 USE_SUDO 决定如何执行 docker info
    if [ "$USE_SUDO" = true ]; then
        DOCKER_CMD="sudo docker"
    else
        DOCKER_CMD="docker"
    fi
    
    # 检查 Docker 是否运行
    if ! $DOCKER_CMD info &>/dev/null; then
        echo -e "${YELLOW}警告: Docker 服务未运行${NC}"
        read -p "是否启动 Docker 服务? (y/n): " start_docker
        if [[ "$start_docker" =~ ^[Yy]$ ]]; then
            if command -v systemctl &>/dev/null; then
                run_cmd systemctl start docker
            elif command -v service &>/dev/null; then
                run_cmd service docker start
            else
                echo -e "${RED}无法启动 Docker 服务: 未找到 systemctl 或 service 命令${NC}"
                exit 1
            fi
            
            if [ $? -ne 0 ]; then
                echo -e "${RED}启动 Docker 服务失败${NC}"
                exit 1
            fi
            echo -e "${GREEN}Docker 服务已启动${NC}"
        else
            echo "继续配置，但请注意配置将在 Docker 启动后生效"
        fi
    fi
}

# 检查 Docker 守护进程配置文件是否存在
check_docker_config() {
    if [ ! -d "$DOCKER_CONFIG_DIR" ]; then
        echo -e "${YELLOW}创建 Docker 配置目录...${NC}"
        run_cmd mkdir -p "$DOCKER_CONFIG_DIR"
    fi
    
    if [ ! -f "$DOCKER_CONFIG_FILE" ]; then
        echo -e "${YELLOW}创建 Docker 配置文件...${NC}"
        echo "{}" | run_cmd tee "$DOCKER_CONFIG_FILE" > /dev/null
    fi
    
    # 检查配置文件是否为有效的 JSON
    if ! run_cmd "jq empty \"$DOCKER_CONFIG_FILE\" 2>/dev/null"; then
        echo -e "${RED}错误: Docker 配置文件不是有效的 JSON${NC}"
        echo "当前配置文件内容:"
        run_cmd cat "$DOCKER_CONFIG_FILE"
        read -p "是否重置为空配置? (y/n): " reset_config
        if [[ "$reset_config" =~ ^[Yy]$ ]]; then
            echo "{}" | run_cmd tee "$DOCKER_CONFIG_FILE" > /dev/null
            echo -e "${GREEN}配置文件已重置${NC}"
        else
            echo -e "${RED}请手动修复配置文件后再运行此脚本${NC}"
            exit 1
        fi
    fi
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

# 配置 registry-mirrors
configure_registry_mirrors() {
    echo -e "${BLUE}配置 Docker Registry Mirrors${NC}"
    echo "请输入镜像地址，例如: https://mirror.example.com"
    read -p "镜像地址: " mirror_url
    
    if [ -z "$mirror_url" ]; then
        echo -e "${YELLOW}未提供镜像地址，跳过配置 registry-mirrors${NC}"
        return
    fi
    
    if ! validate_url "$mirror_url"; then
        echo -e "${RED}错误: 无效的 URL 格式${NC}"
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
    
    # 更新配置
    local temp_file=$(mktemp)
    if run_cmd "jq --arg mirror \"$mirror_url\" '.[\"registry-mirrors\"] = [\$mirror]' \"$DOCKER_CONFIG_FILE\" > \"$temp_file\""; then
        run_cmd mv "$temp_file" "$DOCKER_CONFIG_FILE"
        echo -e "${GREEN}Registry mirrors 配置成功${NC}"
    else
        rm "$temp_file"
        echo -e "${RED}配置 registry-mirrors 失败${NC}"
    fi
}

# 配置 HTTP/HTTPS 代理
configure_proxies() {
    echo -e "${BLUE}配置 Docker HTTP/HTTPS 代理${NC}"
    echo "请输入代理地址（不含协议和端口），例如: proxy.example.com"
    read -p "代理地址: " proxy_host
    
    if [ -z "$proxy_host" ]; then
        echo -e "${YELLOW}未提供代理地址，跳过配置代理${NC}"
        return
    fi
    
    read -p "代理端口: " proxy_port
    
    if ! validate_port "$proxy_port"; then
        echo -e "${RED}错误: 无效的端口号${NC}"
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
    
    local temp_file=$(mktemp)
    
    # 获取当前配置
    local current_config=$(run_cmd "cat \"$DOCKER_CONFIG_FILE\"")
    
    if [[ "$configure_http" =~ ^[Yy]$ ]]; then
        http_proxy="http://${proxy_host}:${proxy_port}"
        current_config=$(echo "$current_config" | jq --arg proxy "$http_proxy" '.["proxies"]["http-proxy"] = $proxy')
    fi
    
    if [[ "$configure_https" =~ ^[Yy]$ ]]; then
        https_proxy="http://${proxy_host}:${proxy_port}"
        current_config=$(echo "$current_config" | jq --arg proxy "$https_proxy" '.["proxies"]["https-proxy"] = $proxy')
    fi
    
    echo "$current_config" > "$temp_file"
    
    if jq empty "$temp_file" 2>/dev/null; then
        run_cmd mv "$temp_file" "$DOCKER_CONFIG_FILE"
        echo -e "${GREEN}代理配置成功${NC}"
    else
        rm "$temp_file"
        echo -e "${RED}配置代理失败: JSON 格式错误${NC}"
    fi
}

# 清除配置
clear_configuration() {
    echo -e "${BLUE}清除 Docker 代理配置${NC}"
    read -p "是否清除 registry-mirrors 配置? (y/n): " clear_mirrors
    read -p "是否清除 HTTP/HTTPS 代理配置? (y/n): " clear_proxies
    
    local temp_file=$(mktemp)
    
    if [[ "$clear_mirrors" =~ ^[Yy]$ ]]; then
        run_cmd "jq 'del(.[\"registry-mirrors\"])' \"$DOCKER_CONFIG_FILE\" > \"$temp_file\""
        run_cmd mv "$temp_file" "$DOCKER_CONFIG_FILE"
        echo -e "${GREEN}Registry mirrors 配置已清除${NC}"
    fi
    
    if [[ "$clear_proxies" =~ ^[Yy]$ ]]; then
        run_cmd "jq 'del(.[\"proxies\"])' \"$DOCKER_CONFIG_FILE\" > \"$temp_file\""
        run_cmd mv "$temp_file" "$DOCKER_CONFIG_FILE"
        echo -e "${GREEN}代理配置已清除${NC}"
    fi
}

# 显示当前配置
show_configuration() {
    echo -e "${BLUE}当前 Docker 代理配置:${NC}"
    
    # 格式化输出 JSON 配置
    echo -e "${GREEN}$(run_cmd "jq . \"$DOCKER_CONFIG_FILE\"")${NC}"
    
    # 检查是否有 registry-mirrors 配置
    if run_cmd "jq -e '.[\"registry-mirrors\"]' \"$DOCKER_CONFIG_FILE\" >/dev/null 2>&1"; then
        echo -e "\n${BLUE}已配置的 Registry Mirrors:${NC}"
        run_cmd "jq -r '.[\"registry-mirrors\"][]' \"$DOCKER_CONFIG_FILE\""
    else
        echo -e "\n${YELLOW}未配置 Registry Mirrors${NC}"
    fi
    
    # 检查是否有代理配置
    if run_cmd "jq -e '.[\"proxies\"]' \"$DOCKER_CONFIG_FILE\" >/dev/null 2>&1"; then
        echo -e "\n${BLUE}已配置的代理:${NC}"
        if run_cmd "jq -e '.[\"proxies\"][\"http-proxy\"]' \"$DOCKER_CONFIG_FILE\" >/dev/null 2>&1"; then
            echo -e "HTTP 代理: $(run_cmd "jq -r '.[\"proxies\"][\"http-proxy\"]' \"$DOCKER_CONFIG_FILE\"")"
        fi
        if run_cmd "jq -e '.[\"proxies\"][\"https-proxy\"]' \"$DOCKER_CONFIG_FILE\" >/dev/null 2>&1"; then
            echo -e "HTTPS 代理: $(run_cmd "jq -r '.[\"proxies\"][\"https-proxy\"]' \"$DOCKER_CONFIG_FILE\"")"
        fi
    else
        echo -e "\n${YELLOW}未配置 HTTP/HTTPS 代理${NC}"
    fi
}

# 重启 Docker 服务
restart_docker() {
    echo -e "${BLUE}重启 Docker 服务以应用更改${NC}"
    read -p "是否现在重启 Docker 服务? (y/n): " restart
    
    if [[ "$restart" =~ ^[Yy]$ ]]; then
        echo "重启 Docker 服务..."
        if command -v systemctl &>/dev/null; then
            run_cmd systemctl restart docker
        elif command -v service &>/dev/null; then
            run_cmd service docker restart
        else
            echo -e "${RED}无法重启 Docker 服务: 未找到 systemctl 或 service 命令${NC}"
            echo "请手动重启 Docker 服务"
            return
        fi
        
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}Docker 服务已重启，配置已生效${NC}"
            
            # 如果用户之前选择了添加到 docker 组并立即访问，修改 socket 权限
            if [ "$(id -u)" -ne 0 ] && id -nG "$CURRENT_USER" | grep -qw "docker"; then
                if [ "$USE_SUDO" = true ]; then
                    echo -e "${BLUE}应用临时 Docker socket 权限...${NC}"
                    if [ -S "$DOCKER_SOCKET" ]; then
                        run_cmd chmod 666 "$DOCKER_SOCKET"
                        if [ $? -eq 0 ]; then
                            echo -e "${GREEN}已应用临时 Docker socket 权限${NC}"
                            echo -e "${YELLOW}您现在可以无需 sudo 使用 Docker，直到下次 Docker 重启${NC}"
                            
                            # 再次测试 Docker 访问权限
                            if docker info &>/dev/null; then
                                echo -e "${GREEN}现在可以无需 sudo 访问 Docker${NC}"
                                USE_SUDO=false
                            fi
                        fi
                    fi
                fi
            fi
        else
            echo -e "${RED}重启 Docker 服务失败${NC}"
            echo "请手动重启 Docker 服务"
        fi
    else
        echo -e "${YELLOW}请记得手动重启 Docker 服务以应用更改${NC}"
    fi
}

# 立即获取 Docker 访问权限
get_immediate_access() {
    if [ "$USE_SUDO" = false ]; then
        echo -e "${GREEN}当前用户已有 Docker 执行权限，无需修改${NC}"
        return
    fi
    
    if [ "$(id -u)" -eq 0 ]; then
        echo -e "${YELLOW}您已经以 root 身份运行，无需修改 socket 权限${NC}"
    else
        if [ -S "$DOCKER_SOCKET" ]; then
            run_cmd chmod 666 "$DOCKER_SOCKET"
            if [ $? -eq 0 ]; then
                echo -e "${GREEN}已修改 Docker socket 权限，您现在可以无需 sudo 使用 Docker${NC}"
                echo -e "${YELLOW}注意: 此权限更改在 Docker 重启后将被重置${NC}"
                
                # 测试 Docker 访问权限
                echo -e "${BLUE}测试 Docker 访问权限...${NC}"
                if docker info &>/dev/null; then
                    echo -e "${GREEN}测试成功! 您现在可以无需 sudo 使用 Docker${NC}"
                    # 更新全局变量，后续操作不使用 sudo
                    USE_SUDO=false
                else
                    echo -e "${RED}访问测试失败，请检查 Docker 配置${NC}"
                fi
            else
                echo -e "${RED}修改 Docker socket 权限失败${NC}"
            fi
        else
            echo -e "${RED}Docker socket 文件不存在: $DOCKER_SOCKET${NC}"
        fi
    fi
}

# 主菜单
main_menu() {
    while true; do
        echo -e "\n${BLUE}========== Docker 代理配置工具 ==========${NC}"
        echo "1. 配置 Registry Mirrors"
        echo "2. 配置 HTTP/HTTPS 代理"
        echo "3. 同时配置 Registry Mirrors 和代理"
        echo "4. 清除配置"
        echo "5. 显示当前配置"
        echo "6. 重启 Docker 服务"
        if [ "$USE_SUDO" = true ]; then
            echo "7. 立即获取 Docker 访问权限 (修改 docker.sock 权限)"
        fi
        echo "0. 退出"
        echo -e "${BLUE}=========================================${NC}"
        
        read -p "请选择操作 [0-7]: " choice
        
        case $choice in
            1)
                configure_registry_mirrors
                ;;
            2)
                configure_proxies
                ;;
            3)
                configure_registry_mirrors
                configure_proxies
                ;;
            4)
                clear_configuration
                ;;
            5)
                show_configuration
                ;;
            6)
                restart_docker
                ;;
            7)
                if [ "$USE_SUDO" = true ]; then
                    get_immediate_access
                else
                    echo -e "${RED}无效的选择，请重试${NC}"
                fi
                ;;
            0)
                echo "感谢使用 Docker 代理配置工具"
                exit 0
                ;;
            *)
                echo -e "${RED}无效的选择，请重试${NC}"
                ;;
        esac
    done
}

# 检查是否已安装必要的工具
check_dependencies() {
    if ! command -v jq &> /dev/null; then
        echo -e "${YELLOW}未检测到 jq 工具，此工具用于处理 JSON 配置${NC}"
        read -p "是否安装 jq? (y/n): " install_jq
        if [[ "$install_jq" =~ ^[Yy]$ ]]; then
            if command -v apt-get &> /dev/null; then
                run_cmd "apt-get update && apt-get install -y jq"
            elif command -v yum &> /dev/null; then
                run_cmd "yum install -y jq"
            elif command -v dnf &> /dev/null; then
                run_cmd "dnf install -y jq"
            elif command -v zypper &> /dev/null; then
                run_cmd "zypper install -y jq"
            elif command -v apk &> /dev/null; then
                run_cmd "apk add jq"
            else
                echo -e "${RED}无法自动安装 jq，请手动安装后再运行此脚本${NC}"
                exit 1
            fi
            
            if [ $? -ne 0 ]; then
                echo -e "${RED}安装 jq 失败${NC}"
                exit 1
            fi
            echo -e "${GREEN}jq 已安装${NC}"
        else
            echo -e "${RED}jq 是必需的，无法继续${NC}"
            exit 1
        fi
    fi
}

# 脚本入口
main() {
    clear
    echo -e "${BLUE}Docker 代理配置工具${NC}"
    echo -e "${YELLOW}此脚本用于配置 Docker 的 registry-mirrors 和 HTTP/HTTPS 代理${NC}"
    
    # 检查依赖
    check_dependencies
    
    # 检查 Docker 是否已安装
    check_docker
    
    # 检查权限
    check_permissions
    
    # 检查 Docker 服务是否运行
    check_docker_running
    
    # 检查并准备 Docker 配置文件
    check_docker_config
    
    # 显示主菜单
    main_menu
}

# 执行主函数
main