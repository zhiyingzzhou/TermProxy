#!/bin/bash

# =========================================
# 终端代理插件安装脚本
# 支持 Bash、Zsh、Oh-My-Zsh、Bash-it
# 版本: 0.0.1
# =========================================

set -euo pipefail  # 严格模式：错误时退出，未定义变量报错，管道错误传播

# ============ 全局配置 ============
readonly SCRIPT_VERSION="0.0.1"
readonly SCRIPT_NAME="$(basename "$0")"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly TEMP_DIR="$(mktemp -d)"
readonly PLUGIN_FILE="${TEMP_DIR}/proxy.plugin.sh"
readonly LOG_FILE="${TEMP_DIR}/install.log"

# 颜色设置 - 现代美观配色方案
readonly GREEN="\033[0;32m"
readonly YELLOW="\033[1;33m"      # 更亮的黄色
readonly RED="\033[0;31m"
readonly BLUE="\033[0;34m"
readonly CYAN="\033[0;36m"        # 青色
readonly PURPLE="\033[0;35m"      # 紫色
readonly BOLD="\033[1m"           # 粗体
readonly BRIGHT_GREEN="\033[1;32m" # 亮绿色
readonly BRIGHT_BLUE="\033[1;34m"  # 亮蓝色
readonly BRIGHT_CYAN="\033[1;36m"  # 亮青色
readonly NC="\033[0m"             # No Color

# 默认配置
readonly DEFAULT_PROXY_HOST="127.0.0.1"
readonly DEFAULT_PROXY_PORT="7890"
readonly DEFAULT_PROXY_PROTOCOL="socks5"
readonly SUPPORTED_PROTOCOLS=("http" "socks5")
readonly MIN_PORT=1
readonly MAX_PORT=65535

# 全局变量
PROXY_HOST=""
PROXY_PORT=""
PROXY_PROTOCOL=""
CURRENT_SHELL=""
INSTALL_MODE="interactive"  # interactive | silent
BACKUP_ENABLED=true
DRY_RUN=false
CUSTOM_INSTALL_DIR=""
UNINSTALL_MODE=false

# ============ 工具函数 ============

# 日志记录函数
log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
    echo "[$timestamp] [$level] $message" >> "$LOG_FILE"
    
    case "$level" in
        ERROR)
            echo -e "${RED}❌ 错误: $message${NC}" >&2
            ;;
        WARN)
            echo -e "${YELLOW}⚠️  警告: $message${NC}" >&2
            ;;
        INFO)
            echo -e "${CYAN}ℹ️  信息: $message${NC}"
            ;;
        SUCCESS)
            echo -e "${GREEN}✅ 成功: $message${NC}"
            ;;
        DEBUG)
            [[ "${DEBUG:-}" == "1" ]] && echo -e "${BLUE}🔍 调试: $message${NC}" >&2
            ;;
    esac
}

# 清理函数
cleanup() {
    local exit_code=$?
    log "DEBUG" "开始清理临时文件..."
    
    if [[ -d "$TEMP_DIR" ]]; then
        rm -rf "$TEMP_DIR" 2>/dev/null || true
    fi
    
    if [[ $exit_code -ne 0 ]]; then
        log "ERROR" "脚本异常退出，退出码: $exit_code"
        echo -e "\n${RED}💥 安装过程中发生错误！${NC}"
        echo -e "${YELLOW}🔍 请检查日志文件: $LOG_FILE${NC}"
        echo -e "${CYAN}📧 如需帮助，请访问: https://github.com/your-repo/issues${NC}"
    fi
    
    exit $exit_code
}

# 设置信号处理
trap cleanup EXIT
trap 'log "WARN" "收到中断信号，正在清理..."; exit 130' INT TERM

# 显示帮助信息
show_help() {
    cat << EOF
${BOLD}${BRIGHT_BLUE}终端代理插件安装脚本 v$SCRIPT_VERSION${NC}

${BOLD}用法:${NC}
    $SCRIPT_NAME [选项]

${BOLD}选项:${NC}
    --host HOST        代理服务器地址 (默认: $DEFAULT_PROXY_HOST)
    --port PORT        代理服务器端口 (默认: $DEFAULT_PROXY_PORT)
    --protocol PROTO   代理协议 (http|socks5, 默认: $DEFAULT_PROXY_PROTOCOL)
    --install-dir DIR  自定义安装目录 (默认: 标准位置)
    --silent           静默安装模式，使用默认值
    --no-backup        跳过配置文件备份
    --dry-run          预览安装操作，不实际执行
    --uninstall        卸载代理插件
    --debug            启用调试模式
    --help, -h         显示此帮助信息
    --version, -v      显示版本信息

${BOLD}示例:${NC}
    $SCRIPT_NAME                                    # 交互式安装
    $SCRIPT_NAME --host 127.0.0.1 --port 8080     # 指定代理配置
    $SCRIPT_NAME --protocol http --silent          # 静默安装 HTTP 代理
    $SCRIPT_NAME --install-dir /opt/proxy          # 自定义安装目录
    $SCRIPT_NAME --dry-run                         # 预览安装过程
    $SCRIPT_NAME --uninstall                       # 卸载插件

${BOLD}支持的 Shell:${NC}
    • Bash (标准 Bash, Bash-it)
    • Zsh (标准 Zsh, Oh-My-Zsh)
    • Fish (手动安装提示)

${BOLD}支持的协议:${NC}
    • http   - HTTP/HTTPS 代理
    • socks5 - SOCKS5 代理

EOF
}

# 显示版本信息
show_version() {
    echo "终端代理插件安装脚本 v$SCRIPT_VERSION"
}

# ============ 验证函数 ============

# 验证主机地址
validate_host() {
    local host="$1"
    
    # 检查是否为空
    if [[ -z "$host" ]]; then
        log "ERROR" "主机地址不能为空"
        return 1
    fi
    
    # 检查长度限制
    if [[ ${#host} -gt 253 ]]; then
        log "ERROR" "主机地址过长 (>253字符)"
        return 1
    fi
    
    # 基本的IP地址或域名格式检查
    if [[ "$host" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        # IPv4 地址验证
        local IFS='.'
        local -a ip_parts=($host)
        for part in "${ip_parts[@]}"; do
            if [[ $part -gt 255 ]]; then
                log "ERROR" "无效的IPv4地址: $host"
                return 1
            fi
        done
    elif [[ ! "$host" =~ ^[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?)*$ ]]; then
        log "ERROR" "无效的主机地址格式: $host"
        return 1
    fi
    
    return 0
}

# 验证端口号
validate_port() {
    local port="$1"
    
    # 检查是否为纯数字
    if [[ ! "$port" =~ ^[0-9]+$ ]]; then
        log "ERROR" "端口号必须为数字: $port"
        return 1
    fi
    
    # 检查端口范围
    if [[ $port -lt $MIN_PORT || $port -gt $MAX_PORT ]]; then
        log "ERROR" "端口号超出有效范围 ($MIN_PORT-$MAX_PORT): $port"
        return 1
    fi
    
    return 0
}

# 验证协议
validate_protocol() {
    local protocol="$1"
    
    # 检查协议是否在支持列表中
    for supported in "${SUPPORTED_PROTOCOLS[@]}"; do
        if [[ "$protocol" == "$supported" ]]; then
            return 0
        fi
    done
    
    log "ERROR" "不支持的协议: $protocol (支持: ${SUPPORTED_PROTOCOLS[*]})"
    return 1
}

# ============ 系统检测函数 ============

# 检查系统依赖
check_dependencies() {
    log "INFO" "检查系统依赖..."
    
    local missing_deps=()
    local required_commands=("curl" "sed" "awk" "grep" "mktemp")
    
    for cmd in "${required_commands[@]}"; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            missing_deps+=("$cmd")
        fi
    done
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        log "ERROR" "缺少必要依赖: ${missing_deps[*]}"
        echo -e "${RED}请安装缺少的命令后重试。${NC}"
        
        # 提供安装建议
        case "$(uname -s)" in
            Darwin*)
                echo -e "${CYAN}macOS 用户可以使用: brew install ${missing_deps[*]}${NC}"
                ;;
            Linux*)
                if command -v apt-get >/dev/null 2>&1; then
                    echo -e "${CYAN}Ubuntu/Debian 用户可以使用: sudo apt-get install ${missing_deps[*]}${NC}"
                elif command -v yum >/dev/null 2>&1; then
                    echo -e "${CYAN}CentOS/RHEL 用户可以使用: sudo yum install ${missing_deps[*]}${NC}"
                elif command -v dnf >/dev/null 2>&1; then
                    echo -e "${CYAN}Fedora 用户可以使用: sudo dnf install ${missing_deps[*]}${NC}"
                fi
                ;;
        esac
        return 1
    fi
    
    log "SUCCESS" "所有依赖检查通过"
    return 0
}

# 检测当前 Shell 环境
detect_shell_environment() {
    log "INFO" "检测 Shell 环境..."
    
    CURRENT_SHELL="$(basename "${SHELL:-/bin/bash}")"
    
    # 详细环境检测
    case "$CURRENT_SHELL" in
        bash)
            log "INFO" "检测到 Bash 环境"
            if [[ -n "${BASH_IT:-}" ]]; then
                log "INFO" "检测到 Bash-it 框架: $BASH_IT"
            fi
            ;;
        zsh)
            log "INFO" "检测到 Zsh 环境"
            if [[ -d "$HOME/.oh-my-zsh" ]]; then
                log "INFO" "检测到 Oh-My-Zsh 框架"
                if [[ -n "${ZSH_CUSTOM:-}" ]]; then
                    log "INFO" "自定义目录: $ZSH_CUSTOM"
                fi
            fi
            ;;
        fish)
            log "WARN" "检测到 Fish Shell，目前仅支持手动安装"
            ;;
        *)
            log "WARN" "未识别的 Shell: $CURRENT_SHELL"
            ;;
    esac
}

# 检查权限
check_permissions() {
    log "INFO" "检查文件权限..."
    
    local test_dirs=(
        "$HOME"
        "${HOME}/.bashrc"
        "${HOME}/.zshrc"
        "${HOME}/.bash_profile"
    )
    
    for path in "${test_dirs[@]}"; do
        if [[ -e "$path" ]] && [[ ! -w "$path" ]]; then
            log "ERROR" "无法写入: $path"
            echo -e "${RED}请检查文件权限或使用 sudo 运行脚本${NC}"
            return 1
        fi
    done
    
    return 0
}

# ============ 输入处理函数 ============

# 解析命令行参数
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --host)
                [[ -n "${2:-}" ]] || { log "ERROR" "--host 参数需要值"; return 1; }
                PROXY_HOST="$2"
                shift 2
                ;;
            --port)
                [[ -n "${2:-}" ]] || { log "ERROR" "--port 参数需要值"; return 1; }
                PROXY_PORT="$2"
                shift 2
                ;;
            --protocol)
                [[ -n "${2:-}" ]] || { log "ERROR" "--protocol 参数需要值"; return 1; }
                PROXY_PROTOCOL="$2"
                shift 2
                ;;
            --install-dir)
                [[ -n "${2:-}" ]] || { log "ERROR" "--install-dir 参数需要值"; return 1; }
                CUSTOM_INSTALL_DIR="$2"
                shift 2
                ;;
            --silent)
                INSTALL_MODE="silent"
                shift
                ;;
            --no-backup)
                BACKUP_ENABLED=false
                shift
                ;;
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            --uninstall)
                UNINSTALL_MODE=true
                shift
                ;;
            --debug)
                export DEBUG=1
                shift
                ;;
            --help|-h)
                show_help
                exit 0
                ;;
            --version|-v)
                show_version
                exit 0
                ;;
            *)
                log "ERROR" "未知参数: $1"
                echo -e "${YELLOW}使用 --help 查看帮助信息${NC}"
                return 1
                ;;
        esac
    done
    
    return 0
}

# 交互式输入
interactive_input() {
    echo -e "${BRIGHT_CYAN}📝 ${BOLD}代理配置设置${NC}"
    echo ""
    
    # 主机地址输入
    while true; do
        read -p "$(echo -e "${CYAN}代理服务器地址 [默认: ${DEFAULT_PROXY_HOST}]: ${NC}")" input_host
        PROXY_HOST="${input_host:-$DEFAULT_PROXY_HOST}"
        
        if validate_host "$PROXY_HOST"; then
            break
        fi
        echo -e "${RED}请重新输入有效的主机地址${NC}"
    done
    
    # 端口输入
    while true; do
        read -p "$(echo -e "${CYAN}代理服务器端口 [默认: ${DEFAULT_PROXY_PORT}]: ${NC}")" input_port
        PROXY_PORT="${input_port:-$DEFAULT_PROXY_PORT}"
        
        if validate_port "$PROXY_PORT"; then
            break
        fi
        echo -e "${RED}请重新输入有效的端口号 (${MIN_PORT}-${MAX_PORT})${NC}"
    done
    
    # 协议选择
    echo -e "${CYAN}请选择代理协议:${NC}"
    local PS3="$(echo -e "${CYAN}请输入选项编号: ${NC}")"
    select proto in "${SUPPORTED_PROTOCOLS[@]}"; do
        if [[ -n "$proto" ]]; then
            PROXY_PROTOCOL="$proto"
            break
        fi
        echo -e "${RED}请输入有效的选项编号${NC}"
    done
    
    # 确认配置
    echo ""
    echo -e "${BRIGHT_CYAN}📋 ${BOLD}配置确认:${NC}"
    echo -e "   ${CYAN}主机地址:${NC} $PROXY_HOST"
    echo -e "   ${CYAN}端口号码:${NC} $PROXY_PORT"
    echo -e "   ${CYAN}代理协议:${NC} $PROXY_PROTOCOL"
    echo ""
    
    while true; do
        read -p "$(echo -e "${YELLOW}确认配置正确吗? [Y/n]: ${NC}")" confirm
        # 转换为小写，兼容老版本 bash
        confirm_lower="$(echo "$confirm" | tr '[:upper:]' '[:lower:]')"
        case "$confirm_lower" in
            y|yes|"")
                break
                ;;
            n|no)
                echo -e "${YELLOW}重新配置...${NC}"
                interactive_input
                return
                ;;
            *)
                echo -e "${RED}请输入 y 或 n${NC}"
                ;;
        esac
    done
}

# ============ 文件操作函数 ============

# 安全移除配置行
safe_remove_config_lines() {
    local rc_file="$1"
    shift
    local patterns=("$@")
    
    local temp_file
    temp_file="$(mktemp)" || {
        log "ERROR" "无法创建临时文件"
        return 1
    }
    
    # 复制原文件内容，过滤掉匹配的行
    local content
    content="$(cat "$rc_file")" || {
        log "ERROR" "无法读取配置文件: $rc_file"
        rm -f "$temp_file"
        return 1
    }
    
    # 逐个过滤模式
    for pattern in "${patterns[@]}"; do
        content="$(echo "$content" | grep -v "$pattern" 2>/dev/null || echo "$content")"
    done
    
    # 写入临时文件
    echo "$content" > "$temp_file" || {
        log "ERROR" "无法写入临时文件"
        rm -f "$temp_file"
        return 1
    }
    
    # 复制回原文件
    cp "$temp_file" "$rc_file" || {
        log "ERROR" "无法更新配置文件: $rc_file"
        rm -f "$temp_file"
        return 1
    }
    
    rm -f "$temp_file"
    return 0
}

# ============ 文件操作函数 ============

# 安全创建文件备份
create_backup() {
    local file="$1"
    
    if [[ ! "$BACKUP_ENABLED" == "true" ]]; then
        return 0
    fi
    
    if [[ -f "$file" ]]; then
        local backup_file="${file}.backup.$(date +%Y%m%d_%H%M%S)"
        if cp "$file" "$backup_file" 2>/dev/null; then
            log "INFO" "已创建备份: $backup_file"
        else
            log "WARN" "无法创建备份文件: $file"
        fi
    fi
}

# 安全检查并创建文件
ensure_file_exists() {
    local file="$1"
    local dir="$(dirname "$file")"
    
    # 创建目录
    if [[ ! -d "$dir" ]]; then
        if [[ "$DRY_RUN" == "true" ]]; then
            log "INFO" "[预览] 将创建目录: $dir"
        else
            mkdir -p "$dir" || {
                log "ERROR" "无法创建目录: $dir"
                return 1
            }
            log "INFO" "已创建目录: $dir"
        fi
    fi
    
    # 创建文件
    if [[ ! -f "$file" ]]; then
        if [[ "$DRY_RUN" == "true" ]]; then
            log "INFO" "[预览] 将创建文件: $file"
        else
            touch "$file" || {
                log "ERROR" "无法创建文件: $file"
                return 1
            }
            log "INFO" "已创建文件: $file"
        fi
    fi
    
    return 0
}

# 安全修改配置文件
modify_config_file() {
    local file="$1"
    local search_pattern="$2"
    local line_to_add="$3"
    
    ensure_file_exists "$file" || return 1
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log "INFO" "[预览] 将在 $file 中添加: $line_to_add"
        return 0
    fi
    
    # 检查是否已存在
    if grep -Fxq "$search_pattern" "$file" 2>/dev/null; then
        log "INFO" "配置已存在于: $file"
        return 0
    fi
    
    # 创建备份
    create_backup "$file"
    
    # 添加配置
    {
        echo ""
        echo "# 代理插件"
        echo "$line_to_add"
    } >> "$file" || {
        log "ERROR" "无法写入文件: $file"
        return 1
    }
    
    log "SUCCESS" "已更新配置文件: $file"
    return 0
}

# ============ 插件生成函数 ============

# 生成代理插件文件
generate_plugin_file() {
    local host="$1"
    local port="$2"
    local protocol="$3"
    local install_path="${4:-unknown}"
    
    log "INFO" "生成代理插件文件..."
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log "INFO" "[预览] 将生成插件文件: $PLUGIN_FILE"
        return 0
    fi
    
    cat > "$PLUGIN_FILE" << EOF
#!/bin/bash
# ==========================================
# 终端代理管理插件
# 版本: $SCRIPT_VERSION
# 自动安装于 $(date '+%Y-%m-%d %H:%M:%S')
# ==========================================

# 代理配置信息
PROXY_HOST="$host"
PROXY_PORT="$port"
PROXY_PROTOCOL="$protocol"

# 环境变量设置函数
_set_proxy_env() {
    export http_proxy="http://\$PROXY_HOST:\$PROXY_PORT"
    export https_proxy="http://\$PROXY_HOST:\$PROXY_PORT"
    export all_proxy="\$PROXY_PROTOCOL://\$PROXY_HOST:\$PROXY_PORT"
    export HTTP_PROXY="http://\$PROXY_HOST:\$PROXY_PORT"
    export HTTPS_PROXY="http://\$PROXY_HOST:\$PROXY_PORT"
    export ALL_PROXY="\$PROXY_PROTOCOL://\$PROXY_HOST:\$PROXY_PORT"
    
    # 设置 no_proxy 避免本地地址走代理
    export no_proxy="localhost,127.0.0.1,::1,.local"
    export NO_PROXY="\$no_proxy"
}

# 清除环境变量函数
_unset_proxy_env() {
    unset http_proxy https_proxy all_proxy HTTP_PROXY HTTPS_PROXY ALL_PROXY no_proxy NO_PROXY
}

# 开启代理
proxy_on() {
    _set_proxy_env
    echo "✅ 代理已开启！"
    proxy_status
}

# 关闭代理
proxy_off() {
    _unset_proxy_env
    echo "❌ 代理已关闭！"
    proxy_status
}

# 查看代理状态
proxy_status() {
    echo "🔍 当前代理状态:"
    if [[ -n "\${http_proxy:-}" ]] || [[ -n "\${HTTP_PROXY:-}" ]]; then
        echo "  📡 HTTP 代理: \${http_proxy:-\$HTTP_PROXY}"
        echo "  🔒 HTTPS 代理: \${https_proxy:-\$HTTPS_PROXY}"
        echo "  🌐 ALL 代理: \${all_proxy:-\$ALL_PROXY}"
        echo "  🚫 忽略代理: \${no_proxy:-\$NO_PROXY}"
        
        echo "🌍 网络连接测试:"
        if command -v curl >/dev/null 2>&1; then
            if curl -s --connect-timeout 5 --max-time 10 https://www.google.com >/dev/null 2>&1; then
            echo "  ✅ 代理工作正常，可以访问 Google"
        else
                echo "  ⚠️  无法访问 Google，请检查代理设置"
            fi
        else
            echo "  ℹ️  curl 未安装，无法测试网络连接"
        fi
    else
        echo "  ❌ 未设置代理"
    fi
}

# 查看代理配置
proxy_config() {
    echo "⚙️  当前代理配置:"
    echo "  🏠 代理主机: \$PROXY_HOST"
    echo "  🔢 代理端口: \$PROXY_PORT"
    echo "  📋 代理协议: \$PROXY_PROTOCOL"
    echo ""
    echo "📁 配置文件位置: $install_path"
    echo "📅 安装时间: $(date '+%Y-%m-%d %H:%M:%S')"
    echo "🏷️  插件版本: $SCRIPT_VERSION"
}

# 测试代理连接
proxy_test() {
    local test_url="\${1:-https://www.google.com}"
    echo "🧪 测试代理连接到: \$test_url"
    
    if command -v curl >/dev/null 2>&1; then
        if curl -s --connect-timeout 10 --max-time 15 "\$test_url" >/dev/null 2>&1; then
            echo "✅ 连接成功"
            return 0
        else
            echo "❌ 连接失败"
            return 1
        fi
    else
        echo "⚠️  curl 未安装，无法测试连接"
        return 1
    fi
}

# 快速切换代理
proxy_toggle() {
    if [[ -n "\${http_proxy:-}" ]] || [[ -n "\${HTTP_PROXY:-}" ]]; then
        proxy_off
    else
        proxy_on
    fi
}

# 修改代理配置
proxy_edit() {
    local old_host="\$PROXY_HOST"
    local old_port="\$PROXY_PORT"
    local old_protocol="\$PROXY_PROTOCOL"
    local config_file="$install_path"
    
    echo "修改代理配置 (留空保持不变):"
    echo -n "代理主机 [\$PROXY_HOST]: "
    read new_host
    echo -n "代理端口 [\$PROXY_PORT]: "
    read new_port
    echo "代理协议选择:"
    echo "1. http"
    echo "2. socks5"
    echo -n "请选择代理协议 [当前: \$PROXY_PROTOCOL]: "
    read protocol_choice
    
    # 设置默认值
    new_host="\${new_host:-\$PROXY_HOST}"
    new_port="\${new_port:-\$PROXY_PORT}"
    
    # 处理协议选择
    case "\$protocol_choice" in
        1) new_protocol="http" ;;
        2) new_protocol="socks5" ;;
        *) new_protocol="\$PROXY_PROTOCOL" ;;
    esac
    
    # 检查端口号格式
    if [[ ! "\$new_port" =~ ^[0-9]+$ ]] || [[ \$new_port -lt 1 ]] || [[ \$new_port -gt 65535 ]]; then
        echo "❌ 无效的端口号: \$new_port"
        return 1
    fi
    
    # 检查主机地址格式（基本检查）
    if [[ -z "\$new_host" ]]; then
        echo "❌ 主机地址不能为空"
        return 1
    fi
    
    # 更新配置
    if [[ "\$new_host" != "\$old_host" ]] || [[ "\$new_port" != "\$old_port" ]] || [[ "\$new_protocol" != "\$old_protocol" ]]; then
        # 更新当前会话的配置变量
        PROXY_HOST="\$new_host"
        PROXY_PORT="\$new_port"
        PROXY_PROTOCOL="\$new_protocol"
        
        # 尝试更新配置文件（如果可写）
        if [[ -f "\$config_file" && -w "\$config_file" ]]; then
            # 创建备份
            cp "\$config_file" "\${config_file}.backup.\$(date +%Y%m%d_%H%M%S)" 2>/dev/null || true
            
                         # 使用更安全的方式更新配置文件
             if command -v sed >/dev/null 2>&1; then
                 sed -i.tmp \\
                     -e "s/PROXY_HOST=\"[^\"]*\"/PROXY_HOST=\"\$new_host\"/g" \\
                     -e "s/PROXY_PORT=\"[^\"]*\"/PROXY_PORT=\"\$new_port\"/g" \\
                     -e "s/PROXY_PROTOCOL=\"[^\"]*\"/PROXY_PROTOCOL=\"\$new_protocol\"/g" \\
                     "\$config_file" 2>/dev/null || true
                 rm -f "\${config_file}.tmp" 2>/dev/null || true
             fi
        fi
        
        echo "✅ 配置已更新！"
        echo "💡 当前会话配置已生效，要永久保存请重新安装插件："
        echo "   ./install.sh --host \$new_host --port \$new_port --protocol \$new_protocol"
        echo ""
        
        # 如果代理当前是开启状态，重新设置环境变量
        if [[ -n "\${http_proxy:-}" ]] || [[ -n "\${HTTP_PROXY:-}" ]]; then
            echo "🔄 重新应用代理设置..."
            _set_proxy_env
        fi
        
        proxy_config
    else
        echo "ℹ️  配置未变更"
    fi
}

# 代理帮助信息
proxy_help() {
    echo "🚀 终端代理插件帮助"
    echo ""
    echo "📋 可用命令:"
    echo "  proxy_on      - 开启代理"
    echo "  proxy_off     - 关闭代理"
    echo "  proxy_edit    - 编辑代理配置"
    echo "  proxy_toggle  - 切换代理状态"
    echo "  proxy_status  - 查看代理状态"
    echo "  proxy_config  - 查看代理配置"
    echo "  proxy_test    - 测试代理连接"
    echo "  proxy_help    - 显示此帮助信息"
    echo ""
    echo "💡 使用示例:"
    echo "  proxy_test https://github.com  - 测试访问 GitHub"
    echo "  proxy_edit                     - 交互式修改代理配置"
}

EOF
    
    # 设置执行权限
    chmod +x "$PLUGIN_FILE" || {
        log "ERROR" "无法设置插件文件权限"
        return 1
    }
    
    log "SUCCESS" "插件文件生成完成"
    return 0
}

# ============ 安装函数 ============

# 通用插件安装函数
install_plugin_to_directory() {
    local plugin_dir="$1"
    local plugin_file="$2"
    local rc_file="$3"
    local source_line="$4"
    local description="$5"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log "INFO" "[预览] 将安装到: $plugin_file"
        [[ -n "$rc_file" ]] && log "INFO" "[预览] 将修改: $rc_file"
        return 0
    fi
    
    # 创建插件目录
    mkdir -p "$plugin_dir" || {
        log "ERROR" "无法创建插件目录: $plugin_dir"
        return 1
    }
    
    # 生成并复制插件文件
    generate_plugin_file "$PROXY_HOST" "$PROXY_PORT" "$PROXY_PROTOCOL" "$plugin_file" || return 1
    cp "$PLUGIN_FILE" "$plugin_file" || {
        log "ERROR" "无法复制插件文件"
        return 1
    }
    
    # 更新配置文件（如果提供）
    if [[ -n "$rc_file" && -n "$source_line" ]]; then
        modify_config_file "$rc_file" "$source_line" "$source_line" || {
            log "ERROR" "无法更新 $rc_file"
            return 1
        }
    fi
    
    log "SUCCESS" "$description"
    return 0
}

# Bash 环境安装
install_bash_plugin() {
    log "INFO" "为 Bash 环境安装代理插件..."
    
    if [[ -n "${BASH_IT:-}" ]]; then
        # Bash-it 环境
        log "INFO" "检测到 Bash-it 环境: $BASH_IT"
        
        local plugin_dir="$BASH_IT/plugins/available"
        local plugin_file="$plugin_dir/proxy.plugin.bash"
        local enabled_link="$BASH_IT/enabled/350---proxy.plugin.bash"
        
        # 使用通用安装函数
        install_plugin_to_directory "$plugin_dir" "$plugin_file" "" "" "Bash-it 代理插件安装完成" || return 1
        
        # Bash-it 特有的启用逻辑
        if [[ "$DRY_RUN" != "true" ]]; then
            if [[ ! -e "$enabled_link" ]]; then
                # 尝试创建符号链接
                if ln -sf "$plugin_file" "$enabled_link" 2>/dev/null; then
                    log "SUCCESS" "已启用 Bash-it 代理插件"
                elif command -v bash-it >/dev/null 2>&1 && bash-it enable plugin proxy 2>/dev/null; then
                    log "SUCCESS" "已通过 bash-it 命令启用代理插件"
                else
                    log "WARN" "请手动启用插件: bash-it enable plugin proxy"
                fi
            else
                log "INFO" "Bash-it 代理插件已启用"
            fi
        else
            log "INFO" "[预览] 将启用 Bash-it 代理插件"
        fi
    else
        # 标准 Bash 环境
        log "INFO" "安装到标准 Bash 环境"
        
        local plugin_dir="${CUSTOM_INSTALL_DIR:-$HOME/.bash_plugins}"
        local plugin_file="$plugin_dir/proxy.plugin.bash"
        local rc_file="$HOME/.bashrc"
        local source_line="source $plugin_file"
        
        install_plugin_to_directory "$plugin_dir" "$plugin_file" "$rc_file" "$source_line" "Bash 代理插件安装完成"
    fi
    
    return 0
}

# Oh-My-Zsh 插件列表更新函数
update_ohmyzsh_plugins() {
    local rc_file="$1"
    
    # 检查是否已经在插件列表中
    if grep -qE '^plugins=.*\bproxy\b' "$rc_file" 2>/dev/null; then
        log "INFO" "proxy 插件已在 Oh-My-Zsh 插件列表中"
        return 0
    fi
    
    create_backup "$rc_file"
    
    if grep -qE '^plugins=\(' "$rc_file" 2>/dev/null; then
        # 插件列表已存在，添加 proxy
        local temp_file
        temp_file="$(mktemp)" || {
            log "ERROR" "无法创建临时文件"
            return 1
        }
        
        awk '
            /^plugins=\(/ {
                if (!/\bproxy\b/) {
                    sub(/plugins=\(/, "plugins=(proxy ")
                }
                print
                next
            }
            { print }
        ' "$rc_file" > "$temp_file" || {
            log "ERROR" "无法处理 .zshrc 文件"
            rm -f "$temp_file"
            return 1
        }
        
        if [[ -s "$temp_file" ]]; then
            cp "$temp_file" "$rc_file" || {
                log "ERROR" "无法更新 .zshrc"
                rm -f "$temp_file"
                return 1
            }
        fi
        rm -f "$temp_file"
    else
        # 插件列表不存在，创建新的
        {
            echo ""
            echo "# Oh-My-Zsh 插件"
            echo "plugins=(proxy)"
        } >> "$rc_file" || {
            log "ERROR" "无法更新 .zshrc"
            return 1
        }
    fi
    
    log "INFO" "已将 proxy 添加到 Oh-My-Zsh 插件列表"
    return 0
}

# Zsh 环境安装
install_zsh_plugin() {
    log "INFO" "为 Zsh 环境安装代理插件..."
    
    if [[ -d "$HOME/.oh-my-zsh" ]]; then
        # Oh-My-Zsh 环境
        log "INFO" "检测到 Oh-My-Zsh 环境"
        
        local custom_dir="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"
        local plugin_dir="$custom_dir/plugins/proxy"
        local plugin_file="$plugin_dir/proxy.plugin.zsh"
        local rc_file="$HOME/.zshrc"
        
        # 使用通用安装函数
        install_plugin_to_directory "$plugin_dir" "$plugin_file" "" "" "Oh-My-Zsh 代理插件安装完成" || return 1
        
        # Oh-My-Zsh 特有的插件列表更新
        if [[ "$DRY_RUN" != "true" ]]; then
            update_ohmyzsh_plugins "$rc_file" || return 1
        fi
    else
        # 标准 Zsh 环境
        log "INFO" "安装到标准 Zsh 环境"
        
        local plugin_dir="${CUSTOM_INSTALL_DIR:-$HOME/.zsh_plugins}"
        local plugin_file="$plugin_dir/proxy.plugin.zsh"
        local rc_file="$HOME/.zshrc"
        local source_line="source $plugin_file"
        
        install_plugin_to_directory "$plugin_dir" "$plugin_file" "$rc_file" "$source_line" "Zsh 代理插件安装完成"
    fi
    
    return 0
}

# Fish Shell 提示
handle_fish_shell() {
    log "WARN" "检测到 Fish Shell"
    
    echo ""
    echo -e "${YELLOW}🐠 Fish Shell 检测${NC}"
    echo ""
    echo -e "${CYAN}Fish Shell 需要手动配置。请参考以下步骤:${NC}"
    echo ""
    echo -e "${BOLD}1. 创建配置目录:${NC}"
    echo "   mkdir -p ~/.config/fish/functions"
    echo ""
    echo -e "${BOLD}2. 创建代理开启函数:${NC}"
    echo "   编辑 ~/.config/fish/functions/proxy_on.fish:"
    echo ""
    echo -e "   ${BLUE}function proxy_on"
    echo "       set -gx http_proxy \"http://$PROXY_HOST:$PROXY_PORT\""
    echo "       set -gx https_proxy \"http://$PROXY_HOST:$PROXY_PORT\""
    echo "       set -gx all_proxy \"$PROXY_PROTOCOL://$PROXY_HOST:$PROXY_PORT\""
    echo "       set -gx no_proxy \"localhost,127.0.0.1,::1,.local\""
    echo "       echo \"✅ 代理已开启\""
    echo "       proxy_status"
    echo -e "   end${NC}"
    echo ""
    echo -e "${BOLD}3. 创建代理关闭函数:${NC}"
    echo "   编辑 ~/.config/fish/functions/proxy_off.fish:"
    echo ""
    echo -e "   ${BLUE}function proxy_off"
    echo "       set -e http_proxy https_proxy all_proxy no_proxy"
    echo "       echo \"❌ 代理已关闭\""
    echo "       proxy_status"
    echo -e "   end${NC}"
    echo ""
    echo -e "${BOLD}4. 创建代理状态函数:${NC}"
    echo "   编辑 ~/.config/fish/functions/proxy_status.fish:"
    echo ""
    echo -e "   ${BLUE}function proxy_status"
    echo "       echo \"🔍 当前代理状态:\""
    echo "       if set -q http_proxy"
    echo "           echo \"  📡 HTTP 代理: \$http_proxy\""
    echo "           echo \"  🔒 HTTPS 代理: \$https_proxy\""
    echo "           echo \"  🌐 ALL 代理: \$all_proxy\""
    echo "           echo \"  🚫 忽略代理: \$no_proxy\""
    echo "       else"
    echo "           echo \"  ❌ 未设置代理\""
    echo "       end"
    echo -e "   end${NC}"
    echo ""
    echo -e "${BOLD}5. 创建代理切换函数:${NC}"
    echo "   编辑 ~/.config/fish/functions/proxy_toggle.fish:"
    echo ""
    echo -e "   ${BLUE}function proxy_toggle"
    echo "       if set -q http_proxy"
    echo "           proxy_off"
    echo "       else"
    echo "           proxy_on"
    echo "       end"
    echo -e "   end${NC}"
    echo ""
    echo -e "${BOLD}6. 重启 Fish Shell 或运行:${NC}"
    echo "   source ~/.config/fish/config.fish"
    echo ""
    echo -e "${CYAN}📖 更多信息请访问: https://fishshell.com/docs/current/tutorial.html${NC}"
    echo ""
    echo -e "${BRIGHT_GREEN}✨ Fish Shell 配置完成后，你可以使用以下命令:${NC}"
    echo -e "   ${BRIGHT_BLUE}proxy_on${NC}      ${CYAN}→${NC} 开启代理"
    echo -e "   ${BRIGHT_BLUE}proxy_off${NC}     ${CYAN}→${NC} 关闭代理"
    echo -e "   ${BRIGHT_BLUE}proxy_toggle${NC}  ${CYAN}→${NC} 切换代理状态"
    echo -e "   ${BRIGHT_BLUE}proxy_status${NC}  ${CYAN}→${NC} 查看代理状态"
    echo ""
}

# ============ 卸载功能 ============

# 卸载 Bash 插件
uninstall_bash_plugin() {
    log "INFO" "卸载 Bash 代理插件..."
    
    local files_to_remove=()
    local rc_file="$HOME/.bashrc"
    
    if [[ -n "${BASH_IT:-}" ]]; then
        # Bash-it 环境
        log "INFO" "检测到 Bash-it 环境"
        
        local plugin_file="$BASH_IT/plugins/available/proxy.plugin.bash"
        local enabled_link="$BASH_IT/enabled/350---proxy.plugin.bash"
        
        if [[ -f "$plugin_file" ]]; then
            files_to_remove+=("$plugin_file")
        fi
        if [[ -L "$enabled_link" ]]; then
            files_to_remove+=("$enabled_link")
        fi
    else
        # 标准 Bash 环境
        local plugin_dir="${CUSTOM_INSTALL_DIR:-$HOME/.bash_plugins}"
        local plugin_file="$plugin_dir/proxy.plugin.bash"
        
        if [[ -f "$plugin_file" ]]; then
            files_to_remove+=("$plugin_file")
        fi
        
        # 检查是否为空目录，如果是则删除
        if [[ -d "$plugin_dir" ]]; then
            # 检查目录是否为空（排除隐藏文件）
            if [[ -z "$(find "$plugin_dir" -mindepth 1 -maxdepth 1 2>/dev/null)" ]]; then
                files_to_remove+=("$plugin_dir")
            fi
        fi
        
        # 从 .bashrc 中移除配置行
        if [[ -f "$rc_file" ]]; then
            local source_line_pattern="source.*proxy\.plugin\.bash"
            if grep -q "$source_line_pattern" "$rc_file"; then
                create_backup "$rc_file"
                safe_remove_config_lines "$rc_file" "# 代理插件" "$source_line_pattern" || {
                    log "ERROR" "无法从 $rc_file 中移除配置"
                    return 1
                }
                log "INFO" "已从 $rc_file 中移除配置"
            fi
        fi
    fi
    
    # 删除文件
    if [[ ${#files_to_remove[@]} -gt 0 ]]; then
        for file in "${files_to_remove[@]}"; do
            if [[ -e "$file" ]]; then
                rm -rf "$file"
                log "SUCCESS" "已删除: $file"
            fi
        done
        log "SUCCESS" "Bash 代理插件卸载完成"
    else
        log "WARN" "未找到需要卸载的 Bash 插件文件"
    fi
}

# 卸载 Zsh 插件
uninstall_zsh_plugin() {
    log "INFO" "卸载 Zsh 代理插件..."
    
    local files_to_remove=()
    local rc_file="$HOME/.zshrc"
    
    if [[ -d "$HOME/.oh-my-zsh" ]]; then
        # Oh-My-Zsh 环境
        log "INFO" "检测到 Oh-My-Zsh 环境"
        
        local custom_dir="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"
        local plugin_dir="$custom_dir/plugins/proxy"
        
        if [[ -d "$plugin_dir" ]]; then
            files_to_remove+=("$plugin_dir")
        fi
        
        # 从 .zshrc 的插件列表中移除 proxy
        if [[ -f "$rc_file" ]]; then
            if grep -qE '^plugins=.*\bproxy\b' "$rc_file"; then
                create_backup "$rc_file"
                # 使用 awk 更安全地处理插件列表
                local temp_file
                temp_file="$(mktemp)" || {
                    log "ERROR" "无法创建临时文件"
                    return 1
                }
                awk '
                    /^plugins=\(/ {
                        gsub(/\bproxy\b[[:space:]]*/, "", $0)
                        gsub(/plugins=\([[:space:]]*/, "plugins=(", $0)
                        gsub(/[[:space:]]*\)/, ")", $0)
                        print
                        next
                    }
                    { print }
                ' "$rc_file" > "$temp_file" || {
                    log "ERROR" "无法处理 .zshrc 文件"
                    rm -f "$temp_file"
                    return 1
                }
                cp "$temp_file" "$rc_file" || {
                    log "ERROR" "无法更新 .zshrc"
                    rm -f "$temp_file"
                    return 1
                }
                rm -f "$temp_file"
                log "INFO" "已从 $rc_file 的插件列表中移除 proxy"
            fi
        fi
    else
        # 标准 Zsh 环境
        local plugin_dir="${CUSTOM_INSTALL_DIR:-$HOME/.zsh_plugins}"
        local plugin_file="$plugin_dir/proxy.plugin.zsh"
        
        if [[ -f "$plugin_file" ]]; then
            files_to_remove+=("$plugin_file")
        fi
        
        # 检查是否为空目录，如果是则删除
        if [[ -d "$plugin_dir" ]]; then
            # 检查目录是否为空（排除隐藏文件）
            if [[ -z "$(find "$plugin_dir" -mindepth 1 -maxdepth 1 2>/dev/null)" ]]; then
                files_to_remove+=("$plugin_dir")
            fi
        fi
        
        # 从 .zshrc 中移除配置行
        if [[ -f "$rc_file" ]]; then
            local source_line_pattern="source.*proxy\.plugin\.zsh"
            if grep -q "$source_line_pattern" "$rc_file"; then
                create_backup "$rc_file"
                safe_remove_config_lines "$rc_file" "# 代理插件" "$source_line_pattern" || {
                    log "ERROR" "无法从 $rc_file 中移除配置"
                    return 1
                }
                log "INFO" "已从 $rc_file 中移除配置"
            fi
        fi
    fi
    
    # 删除文件
    if [[ ${#files_to_remove[@]} -gt 0 ]]; then
        for file in "${files_to_remove[@]}"; do
            if [[ -e "$file" ]]; then
                rm -rf "$file"
                log "SUCCESS" "已删除: $file"
            fi
        done
        log "SUCCESS" "Zsh 代理插件卸载完成"
    else
        log "WARN" "未找到需要卸载的 Zsh 插件文件"
    fi
}

# 执行卸载
perform_uninstall() {
    log "INFO" "开始卸载代理插件..."

case "$CURRENT_SHELL" in
    bash)
            uninstall_bash_plugin
        ;;
    zsh)
            uninstall_zsh_plugin
            ;;
        *)
            log "WARN" "未识别的 Shell: $CURRENT_SHELL"
            echo -e "${YELLOW}📋 请选择卸载方式:${NC}"
            echo "1) 卸载 Bash 插件"
            echo "2) 卸载 Zsh 插件"
            echo "3) 取消卸载"
            
            while true; do
                read -p "$(echo -e "${CYAN}请输入选项 [1-3]: ${NC}")" choice
                case "$choice" in
                    1)
                        uninstall_bash_plugin
                        break
                        ;;
                    2)
                        uninstall_zsh_plugin
                        break
                        ;;
                    3)
                        log "INFO" "用户取消卸载"
                        echo -e "${YELLOW}卸载已取消${NC}"
                        return 0
                        ;;
                    *)
                        echo -e "${RED}请输入有效的选项 (1-3)${NC}"
                        ;;
                esac
            done
            ;;
    esac
    
    echo ""
    echo -e "${BRIGHT_GREEN}┌─────────────────────────────────────────────────┐${NC}"
    echo -e "${BRIGHT_GREEN}│${NC} ${BOLD}${BRIGHT_GREEN}✅ 卸载成功完成！${NC}                        ${BRIGHT_GREEN}│${NC}"
    echo -e "${BRIGHT_GREEN}└─────────────────────────────────────────────────┘${NC}"
    echo ""
    echo -e "${CYAN}💡 ${BOLD}完成卸载后：${NC}"
    echo -e "   1. ${YELLOW}source ~/.${CURRENT_SHELL}rc${NC}  # 重新加载配置"
    echo -e "   2. 所有代理相关命令将不再可用"
    echo -e "   3. 如需重新安装，请再次运行安装脚本"
    echo ""
}

# ============ 主安装流程 ============

# 欢迎信息
show_welcome() {
    echo -e "${BRIGHT_CYAN}╔══════════════════════════════════════════════════╗${NC}"
    echo -e "${BRIGHT_CYAN}║${NC}  ${BOLD}${BRIGHT_BLUE}🚀 终端代理插件安装脚本 v$SCRIPT_VERSION${NC}  ${BRIGHT_CYAN}║${NC}"
    echo -e "${BRIGHT_CYAN}╚══════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${CYAN}此脚本将自动检测你的终端类型并安装代理插件${NC}"
    echo ""
}

# 执行安装
perform_installation() {
    case "$CURRENT_SHELL" in
        bash)
            install_bash_plugin || return 1
            ;;
        zsh)
            install_zsh_plugin || return 1
        ;;
    fish)
            handle_fish_shell
            return 0
        ;;
    *)
            log "WARN" "未识别的 Shell: $CURRENT_SHELL"
            echo -e "${YELLOW}📋 请选择安装方式:${NC}"
        echo "1) 安装为 Bash 插件"
        echo "2) 安装为 Zsh 插件"
            echo "3) 显示 Fish Shell 配置指南"
            echo "4) 取消安装"
            
            while true; do
                read -p "$(echo -e "${CYAN}请输入选项 [1-4]: ${NC}")" choice
                case "$choice" in
                    1)
                        install_bash_plugin || return 1
                        break
                        ;;
                    2)
                        install_zsh_plugin || return 1
                        break
                        ;;
                    3)
                        handle_fish_shell
                        return 0
                        ;;
                    4)
                        log "INFO" "用户取消安装"
                        echo -e "${YELLOW}安装已取消${NC}"
                        exit 0
                        ;;
                    *)
                        echo -e "${RED}请输入有效的选项 (1-4)${NC}"
                ;;
        esac
            done
        ;;
esac
}

# 获取Shell特定的激活说明
get_shell_activation_info() {
    local current_shell="$1"
    
    case "$current_shell" in
        bash)
            if [[ -n "${BASH_IT:-}" ]]; then
                echo -e "${PURPLE}🔄 ${BOLD}激活插件：${NC}"
                echo -e "   ${BRIGHT_CYAN}source ~/.bashrc${NC} 或重启终端"
                echo -e "${CYAN}💡 ${BOLD}Bash-it 说明：${NC}"
                echo -e "   如果插件未自动启用，请运行: ${YELLOW}bash-it enable plugin proxy${NC}"
            else
                echo -e "${PURPLE}🔄 ${BOLD}激活插件：${NC}"
                echo -e "   ${BRIGHT_CYAN}source ~/.bashrc${NC} 或重启终端"
            fi
            ;;
        zsh)
            if [[ -d "$HOME/.oh-my-zsh" ]]; then
                echo -e "${PURPLE}🔄 ${BOLD}激活插件：${NC}"
                echo -e "   ${BRIGHT_CYAN}source ~/.zshrc${NC} 或重启终端"
                echo -e "${CYAN}💡 ${BOLD}Oh-My-Zsh 说明：${NC}"
                echo -e "   插件已添加到 plugins 列表中，无需额外配置"
            else
                echo -e "${PURPLE}🔄 ${BOLD}激活插件：${NC}"
                echo -e "   ${BRIGHT_CYAN}source ~/.zshrc${NC} 或重启终端"
            fi
            ;;
        *)
            echo -e "${PURPLE}🔄 ${BOLD}激活插件：${NC}"
            echo -e "   ${BRIGHT_CYAN}source ~/.${current_shell}rc${NC} 或重启终端"
            ;;
    esac
}

# 显示完成信息
show_completion_message() {
    if [[ "$DRY_RUN" == "true" ]]; then
        echo ""
        echo -e "${BRIGHT_BLUE}┌─────────────────────────────────────┐${NC}"
        echo -e "${BRIGHT_BLUE}│${NC} ${BOLD}${BRIGHT_BLUE}👁️  预览模式完成${NC}                ${BRIGHT_BLUE}│${NC}"
        echo -e "${BRIGHT_BLUE}└─────────────────────────────────────┘${NC}"
        echo ""
        echo -e "${CYAN}🔍 预览摘要:${NC}"
        echo -e "   配置: $PROXY_HOST:$PROXY_PORT ($PROXY_PROTOCOL)"
        echo -e "   目标: $CURRENT_SHELL shell"
        echo -e "${YELLOW}💡 移除 --dry-run 参数以执行实际安装${NC}"
        return
    fi
    
    if [[ "$CURRENT_SHELL" == "fish" ]]; then
        return  # Fish shell 已经显示了配置指南
    fi
    
    echo ""
    echo -e "${BRIGHT_GREEN}┌─────────────────────────────────────────────────┐${NC}"
    echo -e "${BRIGHT_GREEN}│${NC} ${BOLD}${BRIGHT_GREEN}✅ 安装成功完成！${NC}                        ${BRIGHT_GREEN}│${NC}"
    echo -e "${BRIGHT_GREEN}└─────────────────────────────────────────────────┘${NC}"
    echo ""
    echo -e "${BRIGHT_CYAN}📋 ${BOLD}可用命令列表：${NC}"
    echo -e "   ${BRIGHT_BLUE}proxy_on${NC}      ${CYAN}→${NC} 开启代理"
    echo -e "   ${BRIGHT_BLUE}proxy_off${NC}     ${CYAN}→${NC} 关闭代理"
    echo -e "   ${BRIGHT_BLUE}proxy_edit${NC}    ${CYAN}→${NC} 编辑代理配置"
    echo -e "   ${BRIGHT_BLUE}proxy_toggle${NC}  ${CYAN}→${NC} 切换代理状态"
    echo -e "   ${BRIGHT_BLUE}proxy_status${NC}  ${CYAN}→${NC} 查看代理状态"
    echo -e "   ${BRIGHT_BLUE}proxy_config${NC}  ${CYAN}→${NC} 查看代理配置"
    echo -e "   ${BRIGHT_BLUE}proxy_test${NC}    ${CYAN}→${NC} 测试代理连接"
    echo -e "   ${BRIGHT_BLUE}proxy_help${NC}    ${CYAN}→${NC} 显示帮助信息"
    echo ""
    
    # 显示Shell特定的激活信息
    get_shell_activation_info "$CURRENT_SHELL"
    
    echo ""
    echo -e "${CYAN}💡 ${BOLD}快速开始：${NC}"
    echo -e "   1. ${YELLOW}source ~/.${CURRENT_SHELL}rc${NC}  # 重新加载配置"
    echo -e "   2. ${YELLOW}proxy_on${NC}                    # 开启代理"
    echo -e "   3. ${YELLOW}proxy_test${NC}                  # 测试连接"
    echo ""
    
    if [[ "$BACKUP_ENABLED" == "true" ]]; then
        echo -e "${CYAN}📁 配置文件已备份到 .backup.* 文件${NC}"
    fi
    
    echo -e "${CYAN}📊 日志文件: $LOG_FILE${NC}"
}

# ============ 主函数 ============

main() {
    # 解析命令行参数
    if ! parse_arguments "$@"; then
        exit 1
    fi
    
    # 如果是卸载模式
    if [[ "$UNINSTALL_MODE" == "true" ]]; then
        detect_shell_environment
        perform_uninstall
        return 0
    fi
    
    # 显示欢迎信息
    show_welcome
    
    # 系统检查
    check_dependencies || exit 1
    check_permissions || exit 1
    detect_shell_environment
    
    # 设置代理配置
    if [[ "$INSTALL_MODE" == "silent" ]]; then
        # 静默模式，使用默认值或命令行参数
        PROXY_HOST="${PROXY_HOST:-$DEFAULT_PROXY_HOST}"
        PROXY_PORT="${PROXY_PORT:-$DEFAULT_PROXY_PORT}"
        PROXY_PROTOCOL="${PROXY_PROTOCOL:-$DEFAULT_PROXY_PROTOCOL}"
        
        log "INFO" "静默安装模式: $PROXY_HOST:$PROXY_PORT ($PROXY_PROTOCOL)"
    else
        # 交互模式
        if [[ -z "$PROXY_HOST" ]] || [[ -z "$PROXY_PORT" ]] || [[ -z "$PROXY_PROTOCOL" ]]; then
            interactive_input
        fi
    fi
    
    # 验证配置
    validate_host "$PROXY_HOST" || exit 1
    validate_port "$PROXY_PORT" || exit 1
    validate_protocol "$PROXY_PROTOCOL" || exit 1
    
    log "INFO" "开始安装代理插件..."
    log "INFO" "配置: $PROXY_HOST:$PROXY_PORT ($PROXY_PROTOCOL)"
    log "INFO" "目标 Shell: $CURRENT_SHELL"
    log "INFO" "安装模式: $INSTALL_MODE"
    
    # 执行安装
    perform_installation || {
        log "ERROR" "安装过程失败"
        exit 1
    }
    
    # 显示完成信息
    show_completion_message
    
    log "SUCCESS" "安装流程完成"
}

# 执行主函数
main "$@"