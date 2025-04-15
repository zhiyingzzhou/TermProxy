[🇨🇳 查看中文说明 | View in Chinese](./README.zh-CN.md)

# TermProxy

A universal terminal proxy plugin installer for Bash, Zsh, Oh-My-Zsh, Bash-it, with friendly fish shell tips. Supports both http and socks5 protocols, and can be installed interactively or via command-line arguments.

## Features

- One-click installation of terminal proxy management plugin
- Supports Bash, Zsh, Oh-My-Zsh, Bash-it (auto-detects environment)
- Supports both http and socks5 proxy protocols
- Interactive and non-interactive (command-line) installation
- Automatically modifies `.bashrc`/`.zshrc`/Bash-it/Oh-My-Zsh config files
- Proxy management commands: `proxy_on`, `proxy_off`, `proxy_status`
- Fish shell friendly: provides manual integration tips

## Quick Start

### 1. Download and run the installer

```bash
curl -fsSL https://github.com/zhiyingzzhou/TermProxy/install.sh | bash
```

Or clone and run locally:

```bash
git clone https://github.com/zhiyingzzhou/TermProxy.git
cd TermProxy
bash install.sh
```

### 2. Follow the prompts

- Enter your proxy server address (default: 127.0.0.1)
- Enter your proxy server port (default: 7890)
- Select proxy protocol (http or socks5)

Or use command-line arguments for non-interactive installation:

```bash
bash install.sh --host 127.0.0.1 --port 7890 --protocol socks5
```

## Usage

After installation, reload your shell config:

```bash
source ~/.zshrc   # or ~/.bashrc
```

Then use the following commands in your terminal:

- `proxy_on`      # Enable proxy
- `proxy_off`     # Disable proxy
- `proxy_status`  # Show current proxy status and test connectivity

## Parameters

| Argument      | Description                | Example           |
|---------------|---------------------------|-------------------|
| --host        | Proxy server address       | 127.0.0.1         |
| --port        | Proxy server port          | 7890              |
| --protocol    | Proxy protocol (http/socks5) | socks5         |

## Compatibility

- Bash, Zsh, Oh-My-Zsh, Bash-it (auto-detect)
- Fish shell: not auto-installed, but plugin script can be manually integrated

## Uninstallation

1. Remove the relevant `source` or `plugins` line from your `.bashrc` or `.zshrc`
2. Delete the plugin file from `~/.bash_plugins/` or `~/.zsh_plugins/` or Oh-My-Zsh custom plugins directory

## FAQ

**Q: Does it support Windows?**  
A: No, only Linux/macOS terminals are supported.

**Q: How to change proxy settings after installation?**  
A: Edit the plugin file (`~/.bash_plugins/proxy.plugin.bash` or `~/.zsh_plugins/proxy.plugin.zsh`) and reload your shell config.

**Q: How to use with fish shell?**  
A: Manually copy `/tmp/proxy.plugin.sh` content to your fish config.

## License

MIT