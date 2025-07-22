#!/bin/bash

# Docker 代理配置脚本 - 工具函数模块
# 功能: 提供通用工具函数
# 作者: zhiyingzhou
# 版本: 2.0.0
# 日期: 2024-04-16

# 全局变量
SCRIPT_VERSION="2.0.0"
SCRIPT_NAME=$(basename "$0")

# 主目录相关路径
HOME_DIR="${HOME}"
DATA_DIR="${HOME_DIR}/.docker-proxy-tool"
LOG_DIR="${DATA_DIR}/logs"
BACKUP_DIR="${DATA_DIR}/backups"
LOG_FILE="${LOG_DIR}/docker-proxy.log"

# Docker 相关路径
DOCKER_CONFIG_DIR="/etc/docker"
DOCKER_CONFIG_FILE="${DOCKER_CONFIG_DIR}/daemon.json"
DOCKER_SOCKET="/var/run/docker.sock"

# 用户信息
CURRENT_USER=$(whoami)
USE_SUDO=false

# 系统信息
OS_TYPE=""
OS_VERSION=""
DOCKER_VERSION=""

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # 无颜色

# 初始化脚本
init_script() {
    # 确保目录存在
    mkdir -p "${LOG_DIR}" "${BACKUP_DIR}"
    
    # 初始化日志
    : > "${LOG_FILE}"
    chmod 600 "${LOG_FILE}"
    
    log_info "脚本启动: ${SCRIPT_NAME} v${SCRIPT_VERSION}"
    log_info "用户: ${CURRENT_USER}"
    log_info "日志文件: ${LOG_FILE}"
}

# 日志函数
log() {
    local level=$1
    local message=$2
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local log_message="${timestamp} [${level}] ${message}"
    
    echo -e "${log_message}" >> "${LOG_FILE}"
    
    case $level in
        "ERROR")
            echo -e "${RED}${message}${NC}" ;;
        "WARNING")
            echo -e "${YELLOW}${message}${NC}" ;;
        "SUCCESS")
            echo -e "${GREEN}${message}${NC}" ;;
        "INFO")
            echo -e "${BLUE}${message}${NC}" ;;
        *)
            echo -e "${message}" ;;
    esac
}

log_error() { log "ERROR" "$1"; }
log_warn() { log "WARNING" "$1"; }
log_success() { log "SUCCESS" "$1"; }
log_info() { log "INFO" "$1"; }

# 打印带颜色的标题
print_header() {
    local title="$1"
    local width=50
    local padding=$(( (width - ${#title}) / 2 ))
    
    echo -e "\n${BLUE}$(printf '=%.0s' $(seq 1 $width))${NC}"
    echo -e "${BLUE}$(printf ' %.0s' $(seq 1 $padding))${title}${NC}"
    echo -e "${BLUE}$(printf '=%.0s' $(seq 1 $width))${NC}\n"
}

# 检查操作系统类型
check_os() {
    log_info "检查操作系统..."
    
    if [ "$(uname)" == "Darwin" ]; then
        OS_TYPE="macos"
        OS_VERSION=$(sw_vers -productVersion)
    elif [ -f /etc/os-release ]; then
        OS_TYPE=$(grep -w ID /etc/os-release | cut -d= -f2 | tr -d '"')
        OS_VERSION=$(grep -w VERSION_ID /etc/os-release | cut -d= -f2 | tr -d '"')
    else
        log_error "无法确定操作系统类型"
        exit 1
    fi
    
    log_info "操作系统: ${OS_TYPE} ${OS_VERSION}"
}

# 检查 Docker 版本
check_docker_version() {
    log_info "检查 Docker 版本..."
    
    if command -v docker &> /dev/null; then
        DOCKER_VERSION=$(docker --version | awk '{print $3}' | tr -d ',')
        log_info "Docker 版本: ${DOCKER_VERSION}"
    else
        log_error "Docker 未安装"
        exit 1
    fi
}

# 检查依赖
check_dependencies() {
    log_info "检查依赖工具..."
    
    if ! command -v jq &> /dev/null; then
        log_warn "未检测到 jq 工具，此工具用于处理 JSON 配置"
        read -p "是否安装 jq? (y/n): " install_jq
        if [[ "$install_jq" =~ ^[Yy]$ ]]; then
            install_jq
        else
            log_error "jq 是必需的，无法继续"
            exit 1
        fi
    else
        log_info "jq 已安装"
    fi
}

# 安装 jq
install_jq() {
    log_info "尝试安装 jq..."
    
    local success=false
    
    if [ "$OS_TYPE" == "macos" ]; then
        if command -v brew &> /dev/null; then
            run_cmd brew install jq && success=true
        else
            log_error "macOS 上需要 Homebrew 来安装 jq"
            echo "请先安装 Homebrew: https://brew.sh/"
        fi
    elif command -v apt-get &> /dev/null; then
        run_cmd "apt-get update && apt-get install -y jq" && success=true
    elif command -v yum &> /dev/null; then
        run_cmd "yum install -y jq" && success=true
    elif command -v dnf &> /dev/null; then
        run_cmd "dnf install -y jq" && success=true
    elif command -v zypper &> /dev/null; then
        run_cmd "zypper install -y jq" && success=true
    elif command -v apk &> /dev/null; then
        run_cmd "apk add jq" && success=true
    else
        log_error "无法自动安装 jq，请手动安装后再运行此脚本"
        exit 1
    fi
    
    if [ "$success" = true ]; then
        log_success "jq 已安装"
    else
        log_error "安装 jq 失败"
        exit 1
    fi
}

# 创建备份
create_backup() {
    log_info "创建配置备份..."
    
    if [ ! -f "$DOCKER_CONFIG_FILE" ]; then
        log_warn "配置文件不存在，跳过备份"
        return 0
    fi

    # 确保备份目录存在
    if [ ! -d "$BACKUP_DIR" ]; then
        mkdir -p "$BACKUP_DIR" 2>/dev/null
        if [ $? -ne 0 ]; then
            log_warn "无法创建备份目录: ${BACKUP_DIR}，将跳过备份"
            return 0
        fi
    fi
    
    local timestamp=$(date '+%Y%m%d_%H%M%S')
    local backup_file="${BACKUP_DIR}/daemon.json.${timestamp}"
    
    if [ "$(id -u)" -eq 0 ]; then
        cp "$DOCKER_CONFIG_FILE" "$backup_file"
    elif [ "$USE_SUDO" = true ]; then
        sudo cp "$DOCKER_CONFIG_FILE" "$backup_file"
    else
        cp "$DOCKER_CONFIG_FILE" "$backup_file"
    fi
    
    if [ $? -eq 0 ]; then
        log_success "配置文件已备份到: ${backup_file}"
        # 尝试修改权限，但不强制要求成功
        chmod 600 "$backup_file" 2>/dev/null
        # 忽略 chmod 的返回值
        return 0
    else
        log_error "备份配置文件失败，但操作将继续"
        return 0
    fi
}

# 恢复备份
restore_backup() {
    log_info "恢复配置备份..."
    
    # 检查备份目录是否存在
    if [ ! -d "$BACKUP_DIR" ]; then
        log_error "备份目录不存在: ${BACKUP_DIR}"
        return 1
    fi
    
    # 获取所有备份文件，使用通配符
    local backup_files=()
    if ls "${BACKUP_DIR}"/daemon.json.* &>/dev/null; then
        backup_files=($(ls -t "${BACKUP_DIR}"/daemon.json.* 2>/dev/null))
    fi
    
    if [ ${#backup_files[@]} -eq 0 ]; then
        log_error "没有可用的备份文件"
        return 1
    fi
    
    local latest_backup="${backup_files[0]}"
    log_info "正在恢复备份: ${latest_backup}"
    
    # 检查备份文件是否实际存在
    if [ ! -f "$latest_backup" ]; then
        log_error "备份文件不存在: ${latest_backup}"
        return 1
    fi
    
    # 检查目标目录是否存在
    local target_dir=$(dirname "$DOCKER_CONFIG_FILE")
    if [ ! -d "$target_dir" ]; then
        if [ "$(id -u)" -eq 0 ]; then
            mkdir -p "$target_dir"
        elif [ "$USE_SUDO" = true ]; then
            sudo mkdir -p "$target_dir"
        else
            mkdir -p "$target_dir"
        fi
        
        if [ $? -ne 0 ]; then
            log_error "无法创建目标目录: ${target_dir}"
            return 1
        fi
    fi
    
    # 检查是否需要sudo
    if [ "$(id -u)" -eq 0 ]; then
        # 已经是root用户，直接复制
        cp "$latest_backup" "$DOCKER_CONFIG_FILE"
    elif [ "$USE_SUDO" = true ]; then
        # 非root用户且需要sudo
        sudo cp "$latest_backup" "$DOCKER_CONFIG_FILE"
    else
        # 非root用户且不需要sudo
        cp "$latest_backup" "$DOCKER_CONFIG_FILE"
    fi
    
    if [ $? -eq 0 ]; then
        log_success "已从 ${latest_backup} 恢复配置"
        return 0
    else
        log_error "恢复配置失败"
        return 1
    fi
}

# 执行命令，根据需要添加 sudo
run_cmd() {
    # 记录命令到日志
    log_info "执行命令: $*"
    
    # 检查是否需要sudo
    if [ "$(id -u)" -eq 0 ]; then
        # 已经是root用户，直接执行
        eval "$@"
    elif [ "$USE_SUDO" = true ]; then
        # 非root用户且需要sudo
        sudo bash -c "$*"
    else
        # 非root用户且不需要sudo（已有docker权限）
        eval "$@"
    fi
    
    return $?
}

# 执行 jq 命令
run_jq() {
    if [ "$(id -u)" -eq 0 ]; then
        jq "$@"
    elif [ "$USE_SUDO" = true ] && [[ "$*" == *"$DOCKER_CONFIG_FILE"* ]]; then
        sudo jq "$@"
    else
        jq "$@"
    fi
    
    return $?
}

# 更新配置文件
update_config_file() {
    local source_file=$1
    local target_file=$2
    
    log_info "更新配置文件: ${target_file}"
    
    # 如果目标文件已存在，先备份原始文件到临时文件
    local temp_backup=""
    if [ -f "$target_file" ]; then
        temp_backup=$(mktemp)
        log_info "创建临时备份: ${temp_backup}"
        
        if [ "$(id -u)" -eq 0 ]; then
            cp "$target_file" "$temp_backup"
        elif [ "$USE_SUDO" = true ]; then
            sudo cp "$target_file" "$temp_backup"
        else
            cp "$target_file" "$temp_backup"
        fi
        
        if [ $? -ne 0 ]; then
            log_error "无法创建临时备份，操作取消"
            rm -f "$temp_backup" 2>/dev/null
            return 1
        fi
    fi
    
    # 确保目标目录存在
    local target_dir=$(dirname "$target_file")
    if [ ! -d "$target_dir" ]; then
        log_info "目标目录不存在，尝试创建: ${target_dir}"
        if [ "$(id -u)" -eq 0 ]; then
            mkdir -p "$target_dir"
        elif [ "$USE_SUDO" = true ]; then
            sudo mkdir -p "$target_dir"
        else
            mkdir -p "$target_dir"
        fi
        
        if [ $? -ne 0 ]; then
            log_error "无法创建目标目录: ${target_dir}"
            [ -n "$temp_backup" ] && rm -f "$temp_backup" 2>/dev/null
            return 1
        fi
    fi
    
    # 检查是否需要 sudo
    local ret=0
    if [ "$(id -u)" -eq 0 ]; then
        # 已经是 root 用户，直接复制
        cp "$source_file" "$target_file"
        ret=$?
    elif [ "$USE_SUDO" = true ]; then
        # 非 root 用户且需要 sudo，确保使用 sudo 复制文件
        log_info "使用 sudo 更新配置文件"
        sudo cp "$source_file" "$target_file"
        ret=$?
    else
        # 非 root 用户且不需要 sudo
        cp "$source_file" "$target_file"
        ret=$?
    fi
    
    if [ $ret -eq 0 ]; then
        log_success "配置文件已更新"
        # 成功后删除临时备份
        [ -n "$temp_backup" ] && rm -f "$temp_backup" 2>/dev/null
        return 0
    else
        log_error "更新配置文件失败 (错误码: $ret)"
        
        # 如果有临时备份，则恢复原始文件
        if [ -n "$temp_backup" ] && [ -f "$temp_backup" ]; then
            log_info "正在恢复原始文件..."
            
            if [ "$(id -u)" -eq 0 ]; then
                cp "$temp_backup" "$target_file"
            elif [ "$USE_SUDO" = true ]; then
                sudo cp "$temp_backup" "$target_file"
            else
                cp "$temp_backup" "$target_file"
            fi
            
            if [ $? -eq 0 ]; then
                log_success "已恢复原始文件"
            else
                log_error "恢复原始文件失败，原始文件保存在: ${temp_backup}"
                return 1
            fi
        fi
        
        # 清理临时备份
        [ -n "$temp_backup" ] && rm -f "$temp_backup" 2>/dev/null
        return 1
    fi
} 