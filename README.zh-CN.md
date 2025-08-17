# TermProxy

🚀 终端代理插件自动安装脚本，支持 Bash、Zsh、Oh-My-Zsh、Bash-it。支持 http/socks5 协议、交互/静默安装、自定义安装目录和完整卸载功能。

[![版本](https://img.shields.io/badge/version-0.0.1-blue.svg)](https://github.com/zhiyingzzhou/TermProxy)
[![许可证](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)
[![Shell](https://img.shields.io/badge/shell-bash%2Fzsh-brightgreen.svg)](#兼容性)

## 功能特性

### ✨ 核心功能
- **一键安装** 终端代理管理插件
- **自动检测** Bash、Zsh、Oh-My-Zsh、Bash-it 环境
- **双协议支持** http 和 socks5 代理协议
- **多种安装模式** 交互式、静默、预览模式
- **自动配置** 安全修改 shell 配置文件
- **丰富命令集** 7 个强大的代理管理命令

### 🛡️ 企业级特性
- **自定义安装目录** 灵活部署支持
- **完整卸载功能** 自动清理所有配置
- **配置备份** 支持备份和回滚
- **输入验证** 完整的错误处理机制
- **跨平台兼容** 支持 Linux/macOS
- **详细日志** 便于问题排查
- **预览模式** 安全的操作预览

### 📋 可用命令
- `proxy_on` - 开启代理
- `proxy_off` - 关闭代理
- `proxy_toggle` - 切换代理状态
- `proxy_status` - 查看代理状态并测试连通性
- `proxy_config` - 查看当前代理配置信息
- `proxy_test` - 测试代理连接到指定URL
- `proxy_help` - 显示帮助信息

## 快速开始

### 1. 下载安装

> **国内用户推荐使用 Gitee 镜像仓库，下载速度更快。**  
> **注意：**  
> **不要**使用 `curl ... | bash` 方式直接运行本脚本，否则交互输入会失效。  
> 请先下载脚本到本地，再执行。

#### Gitee 镜像（推荐国内用户）

```bash
curl -fsSL https://gitee.com/zhiyingzhou/TermProxy/raw/main/install.sh -o install.sh
bash install.sh
```

或本地克隆后运行：

```bash
git clone https://gitee.com/zhiyingzhou/TermProxy.git
cd TermProxy
bash install.sh
```

#### GitHub 源仓库

```bash
curl -fsSL https://raw.githubusercontent.com/zhiyingzzhou/TermProxy/main/install.sh -o install.sh
bash install.sh
```

或本地克隆后运行：

```bash
git clone https://github.com/zhiyingzzhou/TermProxy.git
cd TermProxy
bash install.sh
```

### 2. 交互式安装

按提示进行配置：
- 输入代理服务器地址（默认：127.0.0.1）
- 输入代理服务器端口（默认：7890）
- 选择代理协议（http 或 socks5）
- 确认配置信息

### 3. 激活使用

安装完成后，重新加载 shell 配置：

```bash
source ~/.zshrc   # 或 source ~/.bashrc
```

然后开始使用代理命令：

```bash
proxy_on          # 开启代理
proxy_status      # 查看状态
proxy_test        # 测试连接
```

## 安装选项

### 命令行参数

| 参数 | 说明 | 示例 |
|------|------|------|
| `--host HOST` | 代理服务器地址 | `127.0.0.1` |
| `--port PORT` | 代理服务器端口 | `7890` |
| `--protocol PROTO` | 代理协议（http/socks5） | `socks5` |
| `--install-dir DIR` | 自定义安装目录 | `/opt/proxy` |
| `--silent` | 静默安装模式 | - |
| `--no-backup` | 跳过配置备份 | - |
| `--dry-run` | 预览模式（不实际执行） | - |
| `--uninstall` | 卸载插件 | - |
| `--debug` | 启用调试模式 | - |
| `--help, -h` | 显示帮助信息 | - |
| `--version, -v` | 显示版本信息 | - |

### 安装示例

```bash
# 交互式安装
./install.sh

# 静默安装（使用默认设置）
./install.sh --silent

# 自定义配置
./install.sh --host proxy.company.com --port 8080 --protocol http

# 自定义安装目录
./install.sh --install-dir /opt/proxy --silent

# 预览安装过程（不实际修改）
./install.sh --dry-run

# 企业部署
./install.sh --host 10.0.0.100 --port 3128 --protocol http --install-dir /usr/local/share/proxy --silent --no-backup
```

## 安装位置

### 默认安装路径

#### Bash 环境
- **Bash-it**：`$BASH_IT/plugins/available/proxy.plugin.bash`
- **标准 Bash**：`~/.bash_plugins/proxy.plugin.bash`

#### Zsh 环境
- **Oh-My-Zsh**：`${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/proxy/proxy.plugin.zsh`
- **标准 Zsh**：`~/.zsh_plugins/proxy.plugin.zsh`

### 自定义安装
使用 `--install-dir` 指定自定义位置：
```bash
./install.sh --install-dir ~/my-shell-plugins
./install.sh --install-dir /opt/proxy
```

## 卸载方法

### 简单卸载
```bash
./install.sh --uninstall
```

### 预览卸载
```bash
./install.sh --uninstall --dry-run
```

卸载程序将：
- ✅ 自动删除插件文件
- ✅ 清理 shell 配置条目
- ✅ 删除空目录
- ✅ 创建配置备份
- ✅ 支持自定义安装目录

## 高级用法

### 测试代理连接
```bash
proxy_test                           # 测试默认URL（Google）
proxy_test https://github.com        # 测试指定URL
```

### 配置管理
```bash
proxy_config                         # 查看当前配置
proxy_edit                          # 交互式修改配置
```

### 快速切换
```bash
proxy_toggle                        # 切换代理开关
```

## 兼容性

### 支持的Shell
- ✅ **Bash**（3.2+，包括 Bash-it）
- ✅ **Zsh**（包括 Oh-My-Zsh）
- ⚠️ **Fish**（提供手动配置指导）

### 支持的系统
- ✅ **Linux**（所有主要发行版）
- ✅ **macOS**（原生和 Homebrew bash/zsh）
- ✅ **Windows WSL**（所有版本）

### 支持的协议
- ✅ **HTTP/HTTPS** 代理
- ✅ **SOCKS5** 代理

## 故障排除

### 常见问题

**Q: 可以用 `curl ... | bash` 方式安装吗？**  
A: 不可以。此方式下交互输入会失效。请先下载脚本到本地再运行。

**Q: 安装时提示权限错误？**  
A: 确保对home目录和shell配置文件有写入权限。

**Q: 安装后如何修改代理设置？**  
A: 使用 `proxy_edit` 命令交互式修改，或 `./install.sh --uninstall && ./install.sh` 重新安装。

**Q: 如何在企业防火墙环境使用？**  
A: 使用 `--install-dir` 安装到可访问位置，并配置适当的代理设置。

**Q: 安装后找不到代理命令？**  
A: 运行 `source ~/.bashrc`（或 `~/.zshrc`）重新加载shell配置。

### 调试模式
启用调试模式进行详细故障排除：
```bash
./install.sh --debug
```

### 日志文件
安装日志保存到临时目录，便于问题排查。

## 企业部署

### 自动化部署
```bash
# 跨多台服务器部署
./install.sh --host proxy.corp.com --port 8080 --protocol http --silent --install-dir /opt/proxy

# 批量部署脚本
for server in server1 server2 server3; do
    ssh $server 'curl -fsSL https://your-repo/install.sh -o install.sh && bash install.sh --silent'
done
```

### 配置管理
- 在受控环境中使用 `--no-backup` 跳过备份
- 使用 `--dry-run` 在执行前测试部署
- 使用 `--install-dir` 自定义安装路径

## 贡献

欢迎贡献代码！请随时提交 Pull Request。

## 许可证

MIT 许可证。

---

⭐ 如果这个项目对你有帮助，请给它一个星标！