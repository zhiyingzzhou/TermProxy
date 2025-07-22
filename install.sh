#!/bin/bash

# =========================================
# 终端代理插件自动安装脚本
# 支持 Bash、Zsh、Oh-My-Zsh、Bash-it，fish shell 友好提示
# 支持 http/socks5 协议选择，支持命令行参数自动化安装
# =========================================
set -e

# 颜色设置
GREEN="\033[0;32m"
YELLOW="\033[0;33m"
RED="\033[0;31m"
BLUE="\033[0;34m"
NC="\033[0m" # No Color

# trap 保证临时文件清理
trap 'rm -f /tmp/proxy.plugin.sh' EXIT

# 欢迎信息
function welcome() {
    echo -e "${BLUE}=== 终端代理插件安装脚本 ===${NC}"
    echo "此脚本将自动检测你的终端类型并安装代理插件"
}

# 检查依赖
function check_deps() {
    if ! command -v curl >/dev/null 2>&1; then
        echo -e "${RED}未检测到 curl，请先安装 curl${NC}"
        exit 1
    fi
}

# 检查 rc 文件是否存在，不存在则创建
function ensure_rc_file() {
    local rc_file="$1"
    if [ ! -f "$rc_file" ]; then
        touch "$rc_file"
        echo -e "${YELLOW}已创建配置文件: $rc_file${NC}"
    fi
}

# 解析命令行参数
function parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --host)
                ARG_PROXY_HOST="$2"; shift 2;;
            --port)
                ARG_PROXY_PORT="$2"; shift 2;;
            --protocol)
                ARG_PROXY_PROTOCOL="$2"; shift 2;;
            *)
                echo -e "${RED}未知参数: $1${NC}"; exit 1;;
        esac
    done
}

# 交互式输入
function interactive_input() {
    read -p "请输入代理服务器地址 [默认: $DEFAULT_PROXY_HOST]: " PROXY_HOST
    PROXY_HOST=${PROXY_HOST:-$DEFAULT_PROXY_HOST}
    read -p "请输入代理服务器端口 [默认: $DEFAULT_PROXY_PORT]: " PROXY_PORT
    PROXY_PORT=${PROXY_PORT:-$DEFAULT_PROXY_PORT}
    echo -e "${YELLOW}请选择代理协议:${NC}"
    select PROXY_PROTOCOL in "http" "socks5"; do
        [ -n "$PROXY_PROTOCOL" ] && break
        echo "请输入 1 或 2 选择协议"
    done
}

# 创建插件内容
function create_plugin_file() {
    local host="$1"
    local port="$2"
    local protocol="$3"
    cat > /tmp/proxy.plugin.sh << EOF
# 终端代理管理插件
# 自动安装于 $(date)

# 代理配置信息
PROXY_HOST="$host"
PROXY_PORT="$port"
PROXY_PROTOCOL="$protocol"

# 开启代理
proxy_on() {
    export http_proxy="http://\$PROXY_HOST:\$PROXY_PORT"
    export https_proxy="http://\$PROXY_HOST:\$PROXY_PORT"
    export all_proxy="\$PROXY_PROTOCOL://\$PROXY_HOST:\$PROXY_PORT"
    export HTTP_PROXY="http://\$PROXY_HOST:\$PROXY_PORT"
    export HTTPS_PROXY="http://\$PROXY_HOST:\$PROXY_PORT"
    export ALL_PROXY="\$PROXY_PROTOCOL://\$PROXY_HOST:\$PROXY_PORT"
    echo "✅ 代理已开启！"
    proxy_status
}

# 关闭代理
proxy_off() {
    unset http_proxy https_proxy all_proxy HTTP_PROXY HTTPS_PROXY ALL_PROXY
    echo "❌ 代理已关闭！"
    proxy_status
}

# 查看代理状态
proxy_status() {
    echo "当前代理状态:"
    if [ -n "\$http_proxy" ] || [ -n "\$HTTP_PROXY" ]; then
        echo "  HTTP 代理: \${http_proxy:-\$HTTP_PROXY}"
        echo "  HTTPS 代理: \${https_proxy:-\$HTTPS_PROXY}"
        echo "  ALL 代理: \${all_proxy:-\$ALL_PROXY}"
        echo "网络连接测试:"
        if curl -s --connect-timeout 5 https://www.google.com >/dev/null 2>&1; then
            echo "  ✅ 代理工作正常，可以访问 Google"
        else
            echo "  ⚠️ 无法访问 Google，请检查代理设置"
        fi
    else
        echo "  ❌ 未设置代理"
    fi
}

# 查看代理配置
proxy_config() {
    echo "当前代理配置:"
    echo "  代理主机: \$PROXY_HOST"
    echo "  代理端口: \$PROXY_PORT"
    echo "  代理协议: \$PROXY_PROTOCOL"
    echo ""
    echo "配置文件位置: $(dirname "\${BASH_SOURCE[0]}")"
}

# 修改代理配置
proxy_edit() {
    local old_host="\$PROXY_HOST"
    local old_port="\$PROXY_PORT"
    local old_protocol="\$PROXY_PROTOCOL"
    local config_file="\${BASH_SOURCE[0]}"
    
    echo "修改代理配置 (留空保持不变):"
    read -p "代理主机 [\$PROXY_HOST]: " new_host
    read -p "代理端口 [\$PROXY_PORT]: " new_port
    echo "代理协议选择:"
    echo "1. http"
    echo "2. socks5"
    read -p "请选择代理协议 [当前: \$PROXY_PROTOCOL]: " protocol_choice
    
    # 设置默认值
    new_host="\${new_host:-\$PROXY_HOST}"
    new_port="\${new_port:-\$PROXY_PORT}"
    
    # 处理协议选择
    case "\$protocol_choice" in
        1) new_protocol="http" ;;
        2) new_protocol="socks5" ;;
        *) new_protocol="\$PROXY_PROTOCOL" ;;
    esac
    
    # 更新配置
    if [ "\$new_host" != "\$old_host" ] || [ "\$new_port" != "\$old_port" ] || [ "\$new_protocol" != "\$old_protocol" ]; then
        sed -i.bak "s/PROXY_HOST=\"\$old_host\"/PROXY_HOST=\"\$new_host\"/g" "\$config_file"
        sed -i.bak "s/PROXY_PORT=\"\$old_port\"/PROXY_PORT=\"\$new_port\"/g" "\$config_file"
        sed -i.bak "s/PROXY_PROTOCOL=\"\$old_protocol\"/PROXY_PROTOCOL=\"\$new_protocol\"/g" "\$config_file"
        
        # macOS 在使用 sed -i 时会创建备份文件，需要删除
        if [ -f "\${config_file}.bak" ]; then
            rm "\${config_file}.bak"
        fi
        
        # 重新加载更新后的值
        PROXY_HOST="\$new_host"
        PROXY_PORT="\$new_port"
        PROXY_PROTOCOL="\$new_protocol"
        
        echo "✅ 配置已更新！"
        proxy_config
    else
        echo "配置未变更"
    fi
}
EOF
}

# 修改 rc 文件，防止重复添加
function modify_rc_file() {
    local file="$1"
    local search_pattern="$2"
    local line_to_add="$3"
    ensure_rc_file "$file"
    if ! grep -Fxq "$search_pattern" "$file"; then
        echo -e "\n$line_to_add" >> "$file"
    fi
}

# Bash 安装
function install_for_bash() {
    echo -e "${BLUE}正在为 Bash 安装代理插件...${NC}"
    if [ -n "$BASH_IT" ]; then
        echo -e "${GREEN}检测到 Bash-it 环境${NC}"
        mkdir -p "$BASH_IT/plugins/available"
        cp /tmp/proxy.plugin.sh "$BASH_IT/plugins/available/proxy.plugin.bash"
        if ! grep -q "proxy.plugin.bash" "$BASH_IT/enabled/350---proxy.plugin.bash" 2>/dev/null; then
            ln -sf "$BASH_IT/plugins/available/proxy.plugin.bash" "$BASH_IT/enabled/350---proxy.plugin.bash" 2>/dev/null || \
            bash-it enable plugin proxy 2>/dev/null || \
            echo -e "${YELLOW}请手动启用插件: bash-it enable plugin proxy${NC}"
        fi
        echo -e "${GREEN}Bash-it 代理插件安装完成!${NC}"
    else
        echo -e "${GREEN}检测到标准 Bash 环境${NC}"
        mkdir -p ~/.bash_plugins
        cp /tmp/proxy.plugin.sh ~/.bash_plugins/proxy.plugin.bash
        modify_rc_file ~/.bashrc "source ~/.bash_plugins/proxy.plugin.bash" "# 代理插件\nsource ~/.bash_plugins/proxy.plugin.bash"
        echo -e "${GREEN}Bash 代理插件安装完成!${NC}"
    fi
}

# Zsh 安装
function install_for_zsh() {
    echo -e "${BLUE}正在为 Zsh 安装代理插件...${NC}"
    if [ -d "$HOME/.oh-my-zsh" ]; then
        echo -e "${GREEN}检测到 Oh-My-Zsh 环境${NC}"
        mkdir -p ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/proxy
        cp /tmp/proxy.plugin.sh ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/proxy/proxy.plugin.zsh
        if ! grep -qE '^plugins=.*\bproxy\b' ~/.zshrc; then
            if grep -qE '^plugins=\(' ~/.zshrc; then
                temp_file=$(mktemp)
                awk '{
                    if ($0 ~ /^plugins=\(/) {
                        if ($0 !~ /\bproxy\b/) {
                            sub(/plugins=\(/, "plugins=(proxy ");
                        }
                        print;
                    } else {print}
                }' ~/.zshrc > "$temp_file"
                if [ -s "$temp_file" ]; then
                    cp "$temp_file" ~/.zshrc
                fi
                rm "$temp_file"
            else
                echo -e "\n# Oh-My-Zsh 插件" >> ~/.zshrc
                echo "plugins=(proxy)" >> ~/.zshrc
            fi
        fi
        echo -e "${GREEN}Oh-My-Zsh 代理插件安装完成!${NC}"
    else
        echo -e "${GREEN}检测到标准 Zsh 环境${NC}"
        mkdir -p ~/.zsh_plugins
        cp /tmp/proxy.plugin.sh ~/.zsh_plugins/proxy.plugin.zsh
        modify_rc_file ~/.zshrc "source ~/.zsh_plugins/proxy.plugin.zsh" "# 代理插件\nsource ~/.zsh_plugins/proxy.plugin.zsh"
        echo -e "${GREEN}Zsh 代理插件安装完成!${NC}"
    fi
}

# fish shell 检测
function check_fish() {
    if [[ "$CURRENT_SHELL" == "fish" ]]; then
        echo -e "${YELLOW}检测到 fish shell，目前暂不支持自动安装。请手动将 /tmp/proxy.plugin.sh 的内容集成到 fish 配置。${NC}"
        exit 0
    fi
}

# 主流程
welcome
check_deps
parse_args "$@"

DEFAULT_PROXY_HOST="127.0.0.1"
DEFAULT_PROXY_PORT="7890"
DEFAULT_PROXY_PROTOCOL="socks5"

PROXY_HOST="${ARG_PROXY_HOST:-$DEFAULT_PROXY_HOST}"
PROXY_PORT="${ARG_PROXY_PORT:-$DEFAULT_PROXY_PORT}"
PROXY_PROTOCOL="${ARG_PROXY_PROTOCOL:-$DEFAULT_PROXY_PROTOCOL}"

if [ -z "$ARG_PROXY_HOST" ] || [ -z "$ARG_PROXY_PORT" ] || [ -z "$ARG_PROXY_PROTOCOL" ]; then
    interactive_input
    PROXY_HOST=${PROXY_HOST:-$DEFAULT_PROXY_HOST}
    PROXY_PORT=${PROXY_PORT:-$DEFAULT_PROXY_PORT}
    PROXY_PROTOCOL=${PROXY_PROTOCOL:-$DEFAULT_PROXY_PROTOCOL}
fi

create_plugin_file "$PROXY_HOST" "$PROXY_PORT" "$PROXY_PROTOCOL"

CURRENT_SHELL=$(basename "$SHELL")
check_fish

case "$CURRENT_SHELL" in
    bash)
        install_for_bash
        ;;
    zsh)
        install_for_zsh
        ;;
    fish)
        # 已在 check_fish 处理
        ;;
    *)
        echo -e "${YELLOW}未能识别的 Shell 类型: $CURRENT_SHELL${NC}"
        echo -e "请选择安装方式:"
        echo "1) 安装为 Bash 插件"
        echo "2) 安装为 Zsh 插件"
        read -p "请输入选项 [1/2]: " shell_choice
        case "$shell_choice" in
            1)
                install_for_bash
                ;;
            2)
                install_for_zsh
                ;;
            *)
                echo -e "${RED}无效的选择，安装已取消${NC}"
                exit 1
                ;;
        esac
        ;;
esac

# 完成消息
echo -e "${BLUE}=== 安装完成 ===${NC}"
echo -e "${GREEN}代理插件已成功安装!${NC}"
echo -e "重新加载你的 Shell 配置后，你可以使用以下命令:"
echo -e "  ${YELLOW}proxy_on${NC}     - 开启代理"
echo -e "  ${YELLOW}proxy_off${NC}    - 关闭代理"
echo -e "  ${YELLOW}proxy_status${NC} - 查看代理状态"
echo -e "\n请运行以下命令使更改生效:"
echo -e "  ${BLUE}source ~/.${CURRENT_SHELL}rc${NC}"