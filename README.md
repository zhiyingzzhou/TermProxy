[🇨🇳 查看中文说明 | View in Chinese](./README.zh-CN.md)

# TermProxy

🚀 An terminal proxy plugin installer for Bash, Zsh, Oh-My-Zsh, Bash-it. Supports http/socks5 protocols, interactive/silent installation, custom installation directories, and complete uninstallation.

[![Version](https://img.shields.io/badge/version-0.0.1-blue.svg)](https://github.com/zhiyingzzhou/TermProxy)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)
[![Shell](https://img.shields.io/badge/shell-bash%2Fzsh-brightgreen.svg)](#compatibility)

## Features

### ✨ Core Features
- **One-click installation** of terminal proxy management plugin
- **Auto-detection** of Bash, Zsh, Oh-My-Zsh, Bash-it environments
- **Dual protocol support**: http and socks5 proxy protocols
- **Multiple installation modes**: interactive, silent, and preview
- **Automatic configuration**: modifies shell config files safely
- **Rich command set**: 7 powerful proxy management commands

### 🛡️ Enterprise Features
- **Custom installation directories** for flexible deployment
- **Complete uninstallation** with automatic cleanup
- **Configuration backup** and rollback support
- **Input validation** and error handling
- **Cross-platform compatibility** (Linux/macOS)
- **Comprehensive logging** for troubleshooting
- **Dry-run mode** for safe preview

### 📋 Available Commands
- `proxy_on` - Enable proxy
- `proxy_off` - Disable proxy  
- `proxy_toggle` - Toggle proxy state
- `proxy_status` - Show current proxy status and test connectivity
- `proxy_config` - View current proxy configuration
- `proxy_test` - Test proxy connection to specified URL
- `proxy_help` - Show help information

## Quick Start

### 1. Download and Install

> **For users in mainland China, it is recommended to use the Gitee mirror repository for faster download.**  
> **Note:**  
> Do **not** use `curl ... | bash` to run this script directly, as interactive input will not work.  
> Please download the script first, then execute it.

#### Gitee Mirror (Recommended for China Mainland Users)

```bash
curl -fsSL https://gitee.com/zhiyingzhou/TermProxy/raw/main/install.sh -o install.sh
bash install.sh
```

Or clone and run locally:

```bash
git clone https://gitee.com/zhiyingzhou/TermProxy.git
cd TermProxy
bash install.sh
```

#### GitHub Source Repository

```bash
curl -fsSL https://raw.githubusercontent.com/zhiyingzzhou/TermProxy/main/install.sh -o install.sh
bash install.sh
```

Or clone and run locally:

```bash
git clone https://github.com/zhiyingzzhou/TermProxy.git
cd TermProxy
bash install.sh
```

### 2. Interactive Installation

Follow the prompts to configure:
- Enter your proxy server address (default: 127.0.0.1)
- Enter your proxy server port (default: 7890)
- Select proxy protocol (http or socks5)
- Confirm your configuration

### 3. Activate and Use

After installation, reload your shell config:

```bash
source ~/.zshrc   # or ~/.bashrc
```

Then start using proxy commands:

```bash
proxy_on          # Enable proxy
proxy_status      # Check status
proxy_test        # Test connection
```

## Installation Options

### Command Line Parameters

| Parameter | Description | Example |
|-----------|-------------|---------|
| `--host HOST` | Proxy server address | `127.0.0.1` |
| `--port PORT` | Proxy server port | `7890` |
| `--protocol PROTO` | Proxy protocol (http/socks5) | `socks5` |
| `--install-dir DIR` | Custom installation directory | `/opt/proxy` |
| `--silent` | Silent installation mode | - |
| `--no-backup` | Skip configuration backup | - |
| `--dry-run` | Preview mode (no actual changes) | - |
| `--uninstall` | Uninstall the plugin | - |
| `--debug` | Enable debug mode | - |
| `--help, -h` | Show help information | - |
| `--version, -v` | Show version information | - |

### Installation Examples

```bash
# Interactive installation
./install.sh

# Silent installation with default settings
./install.sh --silent

# Custom configuration
./install.sh --host proxy.company.com --port 8080 --protocol http

# Custom installation directory
./install.sh --install-dir /opt/proxy --silent

# Preview installation without making changes
./install.sh --dry-run

# Enterprise deployment
./install.sh --host 10.0.0.100 --port 3128 --protocol http --install-dir /usr/local/share/proxy --silent --no-backup
```

## Installation Locations

### Default Installation Paths

#### Bash Environment
- **Bash-it**: `$BASH_IT/plugins/available/proxy.plugin.bash`
- **Standard Bash**: `~/.bash_plugins/proxy.plugin.bash`

#### Zsh Environment  
- **Oh-My-Zsh**: `${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/proxy/proxy.plugin.zsh`
- **Standard Zsh**: `~/.zsh_plugins/proxy.plugin.zsh`

### Custom Installation
Use `--install-dir` to specify custom location:
```bash
./install.sh --install-dir ~/my-shell-plugins
./install.sh --install-dir /opt/proxy
```

## Uninstallation

### Simple Uninstall
```bash
./install.sh --uninstall
```

### Preview Uninstall
```bash
./install.sh --uninstall --dry-run
```

The uninstaller will:
- ✅ Remove plugin files automatically
- ✅ Clean up shell configuration entries  
- ✅ Remove empty directories
- ✅ Create configuration backups
- ✅ Support custom installation directories

## Advanced Usage

### Testing Proxy Connection
```bash
proxy_test                           # Test default URL (Google)
proxy_test https://github.com        # Test specific URL
```

### Configuration Management
```bash
proxy_config                         # View current configuration
proxy_edit                          # Modify configuration interactively
```

### Quick Toggle
```bash
proxy_toggle                        # Switch proxy on/off
```

## Compatibility

### Supported Shells
- ✅ **Bash** (3.2+, including Bash-it)
- ✅ **Zsh** (including Oh-My-Zsh)
- ⚠️ **Fish** (manual setup with provided instructions)

### Supported Systems
- ✅ **Linux** (all major distributions)
- ✅ **macOS** (native and Homebrew bash/zsh)
- ✅ **Windows WSL** (all versions)

### Supported Protocols
- ✅ **HTTP/HTTPS** proxy
- ✅ **SOCKS5** proxy

## Troubleshooting

### Common Issues

**Q: Can I use `curl ... | bash` to install?**  
A: No. Interactive input will not work in this mode. Please download the script first, then run it.

**Q: Installation fails with permission errors?**  
A: Ensure you have write permissions to your home directory and shell config files.

**Q: How to change proxy settings after installation?**  
A: Use `proxy_edit` command for interactive modification, or `./install.sh --uninstall && ./install.sh` to reinstall.

**Q: How to use with corporate firewalls?**  
A: Use `--install-dir` to install in accessible locations and configure appropriate proxy settings.

**Q: Proxy commands not found after installation?**  
A: Run `source ~/.bashrc` (or `~/.zshrc`) to reload your shell configuration.

### Debug Mode
Enable debug mode for detailed troubleshooting:
```bash
./install.sh --debug
```

### Log Files
Installation logs are saved to temporary directory for troubleshooting.

## Enterprise Deployment

### Automated Deployment
```bash
# Deploy across multiple servers
./install.sh --host proxy.corp.com --port 8080 --protocol http --silent --install-dir /opt/proxy

# Batch deployment script
for server in server1 server2 server3; do
    ssh $server 'curl -fsSL https://your-repo/install.sh -o install.sh && bash install.sh --silent'
done
```

### Configuration Management
- Use `--no-backup` to skip backups in controlled environments
- Use `--dry-run` to test deployment before execution
- Customize installation paths with `--install-dir`

## Contributing

We welcome contributions! Please feel free to submit a Pull Request.

## License

MIT License

---

⭐ If this project helps you, please give it a star!