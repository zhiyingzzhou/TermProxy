# TermProxy

一个通用的终端代理插件自动安装脚本，支持 Bash、Zsh、Oh-My-Zsh、Bash-it，fish shell 友好提示。支持 http 和 socks5 协议，可交互或命令行参数安装，适用于生产环境。

## 功能特性

- 一键安装终端代理管理插件
- 自动检测 Bash、Zsh、Oh-My-Zsh、Bash-it 环境
- 支持 http 和 socks5 代理协议
- 支持交互式和非交互式（命令行参数）安装
- 自动修改 `.bashrc`/`.zshrc`/Bash-it/Oh-My-Zsh 配置文件
- 提供 `proxy_on`、`proxy_off`、`proxy_status` 代理管理命令
- fish shell 友好提示：手动集成指引

## 快速开始

### 1. 下载并运行安装脚本

> **注意：**  
> **不要**使用 `curl ... | bash` 方式直接运行本脚本，否则交互输入会失效。  
> 请先下载脚本到本地，再执行。

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

### 2. 按提示输入

- 输入代理服务器地址（默认：127.0.0.1）
- 输入代理服务器端口（默认：7890）
- 选择代理协议（http 或 socks5）

或使用命令行参数自动安装：

```bash
bash install.sh --host 127.0.0.1 --port 7890 --protocol socks5
```

## 使用方法

安装完成后，重新加载 shell 配置：

```bash
source ~/.zshrc   # 或 source ~/.bashrc
```

然后在终端使用以下命令：

- `proxy_on`      # 开启代理
- `proxy_off`     # 关闭代理
- `proxy_status`  # 查看代理状态并测试连通性

## 参数说明

| 参数         | 说明                 | 示例           |
|--------------|----------------------|----------------|
| --host       | 代理服务器地址       | 127.0.0.1      |
| --port       | 代理服务器端口       | 7890           |
| --protocol   | 代理协议（http/socks5） | socks5      |

## 兼容性

- Bash、Zsh、Oh-My-Zsh、Bash-it（自动检测）
- fish shell：暂不自动安装，可手动集成插件脚本

## 卸载方法

1. 删除 `.bashrc` 或 `.zshrc` 中相关的 `source` 或 `plugins` 行
2. 删除 `~/.bash_plugins/`、`~/.zsh_plugins/` 或 Oh-My-Zsh custom plugins 目录下的插件文件

## 常见问题

**Q: 可以用 `curl ... | bash` 方式安装吗？**  
A: 不可以。此方式下交互输入会失效。请先下载脚本到本地再运行。

**Q: 支持 Windows 吗？**  
A: 暂不支持，仅适用于 Linux/macOS 终端。

**Q: 安装后如何修改代理设置？**  
A: 编辑插件文件（如 `~/.bash_plugins/proxy.plugin.bash` 或 `~/.zsh_plugins/proxy.plugin.zsh`），然后重新加载 shell 配置。

**Q: fish shell 如何使用？**  
A: 手动将 `/tmp/proxy.plugin.sh` 内容复制到 fish 配置文件中。

## 许可证

MIT