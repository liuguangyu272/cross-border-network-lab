# 第四篇｜手动部署第一条 WireGuard VPN：Windows → VPS → Internet

> **本篇是可操作的基线实验，不是可以不经测试就承载店铺业务的生产配置。** 参考环境：**全新或专用的 Ubuntu Server 24.04 LTS（亦适用于经过验证的相近 Ubuntu LTS）**、有公网可达 UDP 端口的 VPS、Windows 10/11。2026 年 26.04 LTS 已发布；已有 VPS 不要求重装。若实际系统、现有防火墙或网络条件不同，请先做审计与快照，按发行版适配，不要直接覆盖规则。

## 0. 部署前检查清单（先完成）

- [ ] VPS 控制台可用且已有快照；有持续可用的第二个 SSH 登录窗口。
- [ ] 记下 `VPS_PUBLIC_IP`、实际 SSH TCP 端口 `SSH_PORT`、VPS 出口网卡 `WAN_IF`（来自 `ip route get 1.1.1.1`）。
- [ ] VPS/云安全组允许 UDP/51820；原 SSH 端口仍然允许。
- [ ] 如果 VPS 本身在供应商 CGNAT 或没有入站 UDP 端口转发，则不能直接按本文作为普通公网 WireGuard 服务端，需先处理可达性。
- [ ] UFW 没有与已有 nftables/iptables/firewalld 规则冲突；本节 UFW 路线只适合尚未承载复杂规则的 VPS。
- [ ] `10.66.66.0/24` 不与本机局域网、VPS 云私网或其他 VPN 的地址段冲突；如冲突，整套示例统一换为另一私有网段。

**先预想故障恢复**：服务器上所有配置变动都用备份，`sudo ufw disable` 仅是紧急恢复手段（会降低防护），应通过 VPS Console 执行；服务器不允许这样做的环境应恢复原有规则备份。`sudo systemctl stop wg-quick@wg0` 仅停止 WireGuard，不会撤销 NAT/UFW 的持久规则；具体清理由后文说明。

## 1. 网络结构与地址规划

```text
 Windows                         Internet                           VPS（Ubuntu）
 ┌─────────────────┐         UDP/51820 (encrypted)          ┌───────────────────────────┐
 │ wg tunnel        │───────────────────────────────────────>│ public network interface  │
 │ 10.66.66.2/32    │                                        │ WireGuard wg0 10.66.66.1 │
 │ client privatekey│<───────────────────────────────────────│ IPv4 forwarding + NAT     │
 └─────────────────┘                                         └────────────┬──────────────┘
                                                                       │
                                                                       ▼
                                                              访问正常 HTTPS 网站
```

`/24` 表示该私网网段覆盖约 256 个 IPv4 地址（实际可分配范围要扣除特殊地址）；服务端用 `10.66.66.1/24`，Windows 端使用 `10.66.66.2/32`。这里 WireGuard 的“服务端/客户端”只是教学称呼，技术上两边是 Peer。

## 2. 服务端安装与生成密钥（VPS 上操作）

```bash
cat /etc/os-release
sudo apt update
sudo apt install wireguard curl ufw
sudo install -d -m 700 /etc/wireguard
sudo bash -c 'umask 077; wg genkey > /etc/wireguard/server.key; wg pubkey < /etc/wireguard/server.key > /etc/wireguard/server.pub'
sudo cat /etc/wireguard/server.pub
```

逐行理解：
- `cat` 查看 OS，保证当前仍在预期发行版。
- `apt update` 更新包索引；`apt install` 安装 WireGuard 命令和防火墙工具。
- `install -d -m 700` 建立仅管理员可访问的配置目录。
- `wg genkey` 生成私钥，`wg pubkey` 从私钥生成可共享的公钥；`umask 077` 令新文件默认不对其他用户开放。
- **只复制 `server.pub` 的内容到 Windows 客户端配置，不公开 `server.key`。**

检查权限：

```bash
sudo ls -l /etc/wireguard/server.*
```

不要把私钥传到云笔记、GitHub 或聊天记录。

## 3. Windows 客户端生成密钥

从官方 https://www.wireguard.com/install/ 获取 Windows 安装程序并核对来源。在 WireGuard Windows 中选择 **Add Tunnel → Add Empty Tunnel**（菜单语言可能不同）。软件生成本地私钥和公钥，记录它显示的 **Public key**（仅公钥）供服务器使用。

编辑客户端配置（此时先保存，不启动）：

```ini
[Interface]
PrivateKey = WINDOWS_GENERATED_CLIENT_PRIVATE_KEY
Address = 10.66.66.2/32
DNS = 1.1.1.1

[Peer]
PublicKey = SERVER_PUBLIC_KEY_FROM_SERVER_PUB
Endpoint = VPS_PUBLIC_IP:51820
AllowedIPs = 0.0.0.0/0
PersistentKeepalive = 25
```

**字段说明**：
- `PrivateKey` 是 Windows 本地密钥；不要把字符串占位符原样作为私钥。
- `Address` 是虚拟网卡的内层 IPv4 地址，不是公网 IP。
- `DNS` 是客户端设定的 DNS 服务器；DNS 请求是否经过隧道取决于路由/客户端行为，需要后续验证。
- `[Peer] PublicKey` 必须是 VPS 的公钥，不是自己的公钥。
- `Endpoint` 是 VPS **可达的公网入口**，不是 ISP 代理入口。
- `AllowedIPs=0.0.0.0/0` 意味着请求通过该 Peer 发送全部 IPv4 目标（默认 IPv4 路由）；**不涵盖 IPv6**。
- `PersistentKeepalive=25` 秒用于 NAT 后的客户端保持映射，减少闲置后的不可达问题；它不是失效自动恢复的万能方案。

> [!WARNING]
> 这个首次部署是 **IPv4 教学基线**。在验证第七篇的 IPv6、DNS 和掉线保护之前，不要把它当成高要求的“全流量不泄漏”生产配置，也不要用于需要严格固定网络出口的实际店铺操作。IPv6 默认可能直接走本地网络！

## 4. 配置 VPS Peer（VPS 上操作）

在 VPS 执行：

```bash
sudo nano /etc/wireguard/wg0.conf
```

填入以下内容，将占位符换成**仅本地保存**的实际密钥：

```ini
[Interface]
Address = 10.66.66.1/24
ListenPort = 51820
PrivateKey = SERVER_PRIVATE_KEY_FROM_SERVER_KEY

[Peer]
PublicKey = WINDOWS_CLIENT_PUBLIC_KEY
AllowedIPs = 10.66.66.2/32
```

`SERVER_PRIVATE_KEY_FROM_SERVER_KEY` 要从 VPS 的 `/etc/wireguard/server.key` 读取并只在服务器上使用，不要复制进仓库。`AllowedIPs` 在服务端代表对端能声称的来源地址和相应内部路由，只允许 Windows 的 `10.66.66.2/32`，不要在服务器这个 Peer 上盲目写 `0.0.0.0/0`。

保存之后：

```bash
sudo chmod 600 /etc/wireguard/wg0.conf
sudo wg-quick up wg0
sudo wg show
ip -br addr show wg0
```

`wg-quick up wg0` 创建接口并加载配置，`wg show` 显示 Peer、握手及传输计数；此时 Windows 还没启动 VPN，**暂无握手是正常的**。如果提示配置格式错误，先 `sudo wg-quick down wg0`（只有确实创建过接口时）再检查错别字。不要使用 `systemctl enable` 直到手动连接通过。

## 5. 开启 IP Forwarding（VPS 上操作）

```bash
printf 'net.ipv4.ip_forward=1\n' | sudo tee /etc/sysctl.d/70-wireguard-routing.conf
sudo sysctl -p /etc/sysctl.d/70-wireguard-routing.conf
sysctl net.ipv4.ip_forward
```

预期 `net.ipv4.ip_forward = 1`。第一行创建一个持久文件；第二行加载此文件；第三行验证。该项不会自动设置 NAT，更不会自动让 ISP 代理接入。

**回滚**（仅在明确没有其他业务依赖该配置时）：删除新建的文件，并检查原有转发配置；不要在共享 VPS 上贸然全局设为 0，因为其他业务可能需要它。

## 6. 配置 UFW 与源地址 NAT（VPS 上操作，高风险）

> [!WARNING]
> **确保 VPS Console 可用并已备份，先允许真实 SSH 端口，再开启防火墙。** 如果 UFW 之外已有复杂 netfilter 规则，本节停止，改用现有规则管理体系设计。不要执行 `ufw reset` 或清空 iptables。

先记录接口与现状：

```bash
ip route get 1.1.1.1
sudo ufw status verbose
sudo cp -a /etc/ufw/before.rules /etc/ufw/before.rules.pre-wireguard
```

假设 `ip route get` 看到出站接口是 `ens3`。若不同，请替换以下命令中的 `ens3`。

```bash
# 用服务器实际的 SSH TCP 端口替换 SSH_PORT（可能并非 22）
sudo ufw allow SSH_PORT/tcp
sudo ufw allow 51820/udp
sudo ufw route allow in on wg0 out on ens3 from 10.66.66.0/24 to any
```

解释：前两条允许入站 SSH 和 WireGuard UDP，第三条允许来自 `wg0` 私网的包从公网接口转发。路由许可不等于源地址转换。

**编辑 `/etc/ufw/before.rules`**：

```bash
sudo nano /etc/ufw/before.rules
```

在最前面的 `*filter` 表之前添加以下完整 NAT 表段（**`COMMIT` 必须保留**）：

```iptables
*nat
:POSTROUTING ACCEPT [0:0]
-A POSTROUTING -s 10.66.66.0/24 -o ens3 -j MASQUERADE
COMMIT
```

含义：只对来源是 VPN 子网、且从 `ens3` 出站的 IPv4 包执行 **MASQUERADE（动态源地址 NAT）**。在大部分 VPS 场景，最终出口为 VPS 对外可见的 IPv4。先审阅文件，确认仍包含原有 `*filter`、`COMMIT` 及其他规则。

**检查规则文件语法并启用**：

```bash
sudo sh -c 'iptables-restore --test < /etc/ufw/before.rules'
sudo ufw status verbose
```

上面的 `--test` 只测试文件语法，不会应用规则；若出现错误，请先恢复备份。若 UFW 原本为 `inactive`，在已有 SSH 端口规则、VPS Console 验证后，执行 `sudo ufw enable`。若原本已 `active`，优先在维护窗口使用 `sudo ufw reload`（必要时按 Ubuntu 文档使用安全的停启方法）。这可能短暂影响现有连接，始终保留控制台和第二个 SSH 窗口。

```bash
sudo ufw status numbered
sudo iptables -t nat -S POSTROUTING
sudo iptables -t nat -nvL POSTROUTING
```

`-nvL` 可看计数器；在 Windows 开始联网前值可能为 0。云平台防火墙还必须允许 **UDP/51820** 和真实 SSH TCP 端口。切勿对外开放全部管理端口。

**回滚（VPS Console 中）**：先恢复 `/etc/ufw/before.rules.pre-wireguard` 为 `/etc/ufw/before.rules`（前提是无其他人后续修改），删除本实验添加的精确 UFW 规则，再安全地重载 UFW。若连接已经断开，使用供应商管理控制台而不是反复猜测网络状态。不要为了回滚运行清空整套防火墙的命令。

## 7. 开启 Windows 隧道并验证

在 Windows WireGuard 选择刚编辑的隧道 **Activate**。随后检查：

**Windows PowerShell**：

```powershell
route print -4
ping 10.66.66.1
curl.exe -4 --noproxy "*" https://api.ipify.org
Resolve-DnsName example.com
```

**VPS SSH**：

```bash
sudo wg show
sudo iptables -t nat -nvL POSTROUTING
```

- `wg show` 中应出现最近的 `latest handshake`，且实际发包时 `transfer` 计数增加。
- `ping 10.66.66.1` 成功是好迹象；ICMP 被拦截时不一定成功。
- Windows `curl.exe -4 --noproxy "*"` 的返回地址应与此前记录的 VPS 外网出口地址一致（某些多 IP VPS 可能有所差异）。
- `route print -4` 能看到 WireGuard 的默认 IPv4 路由，才算理解 **为什么访问网站会走 VPS**。

再查看 `curl.exe -6 --noproxy "*" https://api64.ipify.org`：如果 IPv6 仍走本地网络，它暴露了**教学配置尚未解决的泄漏**；不要把此阶段投入实际敏感业务。失败则记录“不具备可用 IPv6 路径/已被阻断”，还要做第七篇的断线和 DNS 验证。

## 8. 服务持久化与恢复

手动完全测试成功后再在 VPS 执行：

```bash
sudo systemctl enable wg-quick@wg0
sudo systemctl status wg-quick@wg0 --no-pager
```

`enable` 让服务在下次开机自动启用（并不意味着 Windows 断网一定自动重连）。如当前已经通过 `wg-quick up` 启动，不要再次 `systemctl start` 同一接口（可能报已存在）。在维护窗口重启时确认服务运行，并再次测 IP。

停止本实验（若无其他业务依赖）：Windows 先 Deactivate，再 VPS `sudo wg-quick down wg0`；持久防火墙/NAT 规则和 systemd enable 状态不会因此自动消失，需要另行撤销。重新启用服务时优先使用 systemd 管理，避免交叉操作。

## 9. 逐项故障诊断（先找原因，再改配置）

| 症状 | 检查 | 常见原因与处理 |
|---|---|---|
| 没有 handshake | `sudo wg show`；云安全组；`sudo ss -lunp` | UDP/51820 未放行、Endpoint/公钥写错、VPS 无公网可达入口 |
| 有 handshake，不能访问 10.66.66.1 | Windows 地址、服务端 AllowedIPs | 内层地址、隧道配置错误 |
| 能 ping 10.66.66.1，但不能访问网页 IP | `sysctl net.ipv4.ip_forward`、UFW route、NAT 计数器 | 转发/源 NAT/云限制问题 |
| 能访问 IP，域名不能解析 | `Resolve-DnsName`、DNS 设置 | DNS 未正确配置/流量未走预期路径 |
| IPv4 成功但 IPv6 从本地出去 | `curl.exe -6`、IPv6 路由 | IPv4-only 配置不涵盖 IPv6，第七篇处理 |
| 访问部分网站卡住 | MTU、IPv6、DNS、特定站点 | 不要先随意把 MTU 统一改为 1280 |

## 10. 核心原理复盘与自测

- **为什么 `AllowedIPs` 两侧不一样？** Windows `0.0.0.0/0` 是经 VPS 发往任意 IPv4 目的地址；VPS `10.66.66.2/32` 是授权该 Peer 使用的 VPN 内层源地址。
- **为什么服务器上需要 `ip_forward=1`？** Linux 需允许从虚拟网卡接收的包转发到外部网卡。
- **为什么还需要 MASQUERADE？** 目的网站通常不知道如何返回到私有 `10.66.66.2`；VPS 用公网出口地址代表该源发出请求。

**验收**：完成“客户端握手—内网可达—IPv4 网站可达—出口 IP 可验证—DNS/IPv6 风险已记录”五项，才进入 ISP 代理章节。

**官方参考（核验日：2026-10-30）**：
- WireGuard 安装: https://www.wireguard.com/install/
- WireGuard Quickstart: https://www.wireguard.com/quickstart/
- Ubuntu Default Gateway: https://ubuntu.com/server/docs/wireguard-vpn-defaultgw/
- Ubuntu UFW 与 NAT: https://ubuntu.com/server/docs/how-to/security/firewalls/
- Ubuntu 故障排查: https://ubuntu.com/server/docs/wireguard-vpn-troubleshooting/
