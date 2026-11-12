# 第三篇｜Linux、SSH 与安全的服务器操作

> 目标：从 Windows 管理自己已有的 VPS；能查看网络、管理服务，并理解如何避免把远程服务器锁死。

## 1. Windows Terminal 与 Linux shell 是两个环境

Windows PowerShell 提示符常形如 `PS C:\Users\...>`；SSH 登录后 VPS shell 可能是 `user@vps:~$`。`sudo`、`apt`、`systemctl` 是 **VPS 上的 Linux 命令**；`ipconfig`、`Get-NetRoute` 是 **Windows 上的命令**。每次复制命令先确认在哪个系统执行。

**Windows 中**：

```powershell
ssh -V
ssh USER@VPS_PUBLIC_IP
```

`USER` 取决于 VPS 镜像（ubuntu、debian、root 或面板指定用户）。`VPS_PUBLIC_IP` 是你实际的服务器地址，不要填写示例 `203.0.113.x`。若 SSH 端口不是 22，可指定 `ssh -p SSH_PORT USER@VPS_PUBLIC_IP`。首次连接会出现主机公钥指纹；应该通过供应商可信渠道核对，不能不假思索接受异常变化。

> [!WARNING]
> 对已经在线上运行的 VPS，在修改 SSH、UFW、防火墙、默认路由之前，必须打开供应商提供的 **VNC/Serial/Rescue Console**，确认可用；保持第二条 SSH 会话、备份配置并记录回滚命令。若无可靠控制台/快照，不要进行破坏性的远程防火墙实验。

## 2. Linux 最小生存技能

| 命令 | 作用 | 实例 |
|---|---|---|
| `pwd`, `ls -la`, `cd` | 看当前位置、文件与切换目录 | `cd /etc` |
| `cat`, `less`, `grep` | 查看/搜索文本 | `cat /etc/os-release` |
| `sudo` | 为当前命令申请管理员权限 | `sudo systemctl status ssh` |
| `apt` | Ubuntu/Debian 包管理 | `sudo apt update` |
| `systemctl` | 管理 systemd 服务 | `systemctl status ssh` |
| `journalctl` | 查看系统日志 | `sudo journalctl -u ssh -n 20 --no-pager` |
| `ip` | 查看地址/路由 | `ip route` |
| `ss` | 查看套接字 | `sudo ss -lntup` |
| `nano` | 文本编辑器 | `sudo nano /etc/example.conf` |
| `cp` | 复制备份文件 | `sudo cp -a src src.bak` |

`rm` 删除不会进入 Windows 回收站；不要随意执行 `rm -rf`。`sudo` 前先确认命令的目标文件和运行环境。

### 实验 1：只读服务器检查

在 **VPS 的 SSH** 运行：

```bash
id
cat /etc/os-release
uname -r
ip -br addr
ip route
ip route get 1.1.1.1
sudo ss -lntup
systemctl status ssh --no-pager
```

如果 `systemctl status ssh` 显示服务 `active (running)` 或你已成功 SSH 登录，即表示当前管理通道可用。发行版不同，服务名可能是 `sshd`。`ip route get 1.1.1.1` 的 `dev` 后面是当前到该目的地址的网络接口名，后续记为 `WAN_IF`。

## 3. SSH 密钥（比公开密码登录更适合长期维护）

**原理**：公钥放在 VPS 上，私钥仅由你的 Windows 保存。服务器通过加密签名挑战确认你持有私钥，而无需把私钥发给服务器。SSH 密钥与 WireGuard 密钥不同，请分开保存。

在 **Windows PowerShell**：

```powershell
ssh-keygen -t ed25519 -C "network-lab" -f "$env:USERPROFILE\.ssh\id_ed25519_networklab"
Get-Content "$env:USERPROFILE\.ssh\id_ed25519_networklab.pub"
```

为私钥设置 passphrase。只复制输出的**公钥**（末尾 `.pub` 文件内容），将它按服务器/面板的公钥配置方式添加到目标用户的 `~/.ssh/authorized_keys`。如手动配置，在 Linux 上检查 `~/.ssh` 权限为 700、`authorized_keys` 为 600 且归属正确用户。

测试（另开一个 PowerShell 窗口，原会话保持不断）：

```powershell
ssh -i "$env:USERPROFILE\.ssh\id_ed25519_networklab" USER@VPS_PUBLIC_IP
```

**只有密钥登录已验证并且有控制台回退通道**，才考虑修改 `/etc/ssh/sshd_config` 禁用密码认证。错误的 SSH 配置会造成远程失联；修改前 `sudo sshd -t` 校验，再通过适当方式 reload SSH 服务，并再次测试新会话。不要关闭当前可用会话直至验证完成。

## 4. 更新与服务

Ubuntu/Debian：

```bash
sudo apt update
sudo apt list --upgradable
sudo apt install wireguard curl ufw
systemctl --version
```

`apt update` 仅更新包索引，不等于升级全部已安装软件；`apt install` 安装包。已有生产服务时，应安排维护窗口和快照后才进行 `apt upgrade`。Ubuntu 通常有 `unattended-upgrades`，检查 `systemctl list-timers | grep apt` 和官方配置，不要盲目开启自动重启。

## 5. 防火墙的两层概念

云平台防火墙/安全组（VPS 之外）与 Linux 主机防火墙（VPS 内）可能都需要允许 UDP/51820。SSH 端口尤其要保留。**不要一边使用现有 nftables/firewalld 系统一边不加审计执行 UFW 重置**；不同工具可能同时影响内核网络过滤规则。

检查（只读）：

```bash
sudo ufw status verbose
sudo nft list ruleset 2>/dev/null | head -n 80
sudo iptables -S
```

若 UFW 是 `inactive`，不意味着服务器完全没有防火墙——还可能存在云端防火墙或其他 netfilter 规则。如果已有复杂防火墙，第四篇的 UFW 分支不适合未经隔离直接实施。

## 本篇验收与自测

- [ ] 能分别指出 Windows PowerShell 和 VPS bash 的命令。
- [ ] SSH 主机密钥指纹已核对，并保留安全控制台。
- [ ] 知道哪一张是 VPS 出口网卡、哪个端口用于 SSH。
- [ ] SSH 密钥测试成功（或明确记录尚未完成）。

1. 问：`apt update` 就已经升级了服务器程序吗？答：没有，它主要刷新软件包索引。
2. 问：`ssh-keygen` 产生的 `.pub` 可以上传 GitHub 吗？答：技术上公钥非秘密，但也不应无目的地公开真实部署资产；私钥绝不能公开。
3. 问：改防火墙前为什么要准备 VPS 控制台？答：如果远程端口被误封，SSH 连接可能消失，需要独立管理通道回滚。

**官方参考（核验日：2026-10-30）**：
- Ubuntu SSH: https://ubuntu.com/server/docs/openssh-server/
- Microsoft OpenSSH Key Management: https://learn.microsoft.com/en-us/windows-server/administration/openssh/openssh_keymanagement
- Ubuntu Firewall: https://ubuntu.com/server/docs/how-to/security/firewalls/
- Ubuntu Automatic Updates: https://ubuntu.com/server/docs/how-to/software/automatic-updates/
