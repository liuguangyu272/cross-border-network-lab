# 从零到初级网络工程实践：Windows + VPS + 静态 ISP 代理跨境电商网络搭建

**完整版中文 Markdown 教材｜最后核验：2026-10-30**  
**适用对象**：Windows 计算机初学者；已拥有 VPS 与静态 ISP 代理；美国、日本合法业务出口与普通海外网站访问。  
**范围说明**：教材是网络工程学习与授权网络部署实践，不保证任何电商平台账号安全、不会自动帮助绕过身份或地区审核。示例配置未经你的真实 VPS 和商家代理服务联机测试。安全风险尤其是 SSH、UFW、路由和 IPv6，务必按文内的前置条件和回滚方案检查。

## 全书学习路线

| 阶段 | 核心问题 | 验收成果 |
|---|---|---|
| 基础 | IP、DNS、TCP/UDP、路由、NAT、VPN、代理如何工作？ | 能画网络包路径与看 Windows 路由表 |
| 审计 | 你的 VPS 与静态 ISP 代理分别提供什么？ | 记录真实系统、出口、协议与认证方式（本地保密） |
| 配置 | Windows 如何安全连上 VPS？ | WireGuard 握手、IPv4 出口、IP 转发与 NAT 验证 |
| 代理 | 为什么 ISP 代理不等于 VPS？ | A/B/C 三条路径实际出口对照 |
| 高级 | DNS、IPv6、Kill Switch、美国/日本分流如何规划？ | 可验证的风险分析与故障测试 |
| 工程化 | 如何排错并制作 GitHub 项目？ | 脱敏测试报告、只读检查脚本、技术 README |

## 课程目录

- [第一篇｜从零理解计算机网络](#part-1)
- [第二篇｜审计你已经购买的 VPS 与静态 ISP 代理](#part-2)
- [第三篇｜Linux、SSH 与安全的服务器操作](#part-3)
- [第四篇｜手动部署第一条 WireGuard VPN：Windows → VPS → Internet](#part-4)
- [第五篇｜接入现有静态 ISP 代理：三种路径逐一验证](#part-5)
- [第六篇｜美国 / 日本多出口：从单节点到策略路由](#part-6)
- [第七篇｜可靠性、安全、IPv6 与防泄漏](#part-7)
- [第八篇｜故障诊断实验与初级网络工程方法](#part-8)
- [第九篇｜把实验整理为 GitHub 工程项目与简历成果](#part-9)
- [官方资料与继续学习路线](#part-10)

---

<a id="part-1"></a>

# 第一篇｜从零理解计算机网络

> 目标：能画出「Windows → 路由器 → ISP → VPS → 目标站点」的数据路径，理解 DNS、TCP/UDP、路由、NAT、TLS 与 VPN/代理的分工。以下示例域名及地址仅作说明；不能把示例地址当真实服务。

## 1. 互联网不是“一根线”

**直观类比**：互联网像很多城市的邮政网络。设备是收发件人，IP 是可路由的地址，路由器是中转站，端口是一个设备内部的收件窗口。数据被拆成多个包（packet），各自可能经过不同网络设备。

**技术原理**：主机发送报文时，应用层负责业务语义，传输层（TCP/UDP）区分会话，网络层（IP）负责寻址和路由，链路层（以太网/Wi-Fi）负责当前一跳传输。OSI 七层模型可辅助理解；实际互联网通常用 TCP/IP 分层模型组织协议。路由器依据目的 IP 和路由表选择下一跳；每经过一跳，链路层封装一般会变化，但 IP 层地址不一定改变（NAT 例外）。

```text
应用层        HTTPS / DNS / SSH / 电商网站
传输层        TCP / UDP：端口、可靠传输（TCP）、数据报（UDP）
网络层        IPv4 / IPv6：源和目的 IP、路由
链路层        Ethernet / Wi-Fi：同一链路上的交付
```

### 实验 1：Windows 看自己在哪个网络

在 **PowerShell（不是 VPS 的 Linux 终端）** 执行：

```powershell
ipconfig /all
route print -4
tracert -4 1.1.1.1
Test-NetConnection 1.1.1.1 -Port 443
```

- `ipconfig /all`：看当前网卡 IPv4、IPv6、DNS、默认网关；不要公开完整截图（可能含内部网络信息）。
- `route print -4`：看 IPv4 路由表；`0.0.0.0/0` 对应 IPv4 默认路由，较长前缀优先匹配。
- `tracert`：尝试显示途中跳点；某些节点不回答 ICMP，显示 `*` 不等于真实断网。
- `Test-NetConnection`：检查目标 TCP 443 端口是否可连接；网络允许时结果中的 `TcpTestSucceeded` 为 True。

**验证**：找出本机私有 IPv4（例如 `192.168.x.x`）、默认网关和 DNS 服务器。**故障**：没有 `tracert` 完整结果并不必然失败；某些网络屏蔽探测报文。

## 2. IP、子网与 CIDR

IPv4 地址长 32 位，写成 `a.b.c.d`；IPv6 长 128 位，常用冒号分隔十六进制表达。`192.168.1.15/24` 中的 `/24` 表示网络前 24 位，即通常这一网段为 `192.168.1.0/24`。`/32` 仅代表一个 IPv4 主机地址，`0.0.0.0/0` 匹配全部 IPv4 地址。IPv6 的全默认路由是 `::/0`。

| 示例 | 含义 | 提醒 |
|---|---|---|
| `10.66.66.2` | 本教材计划使用的 VPN 内部 IPv4 | 不可作为公网出口 IP |
| `192.168.1.10` | 常见家庭/校园内网地址 | 有路由冲突时不能照搬 |
| `203.0.113.5` | 文档示例公网 IP（TEST-NET-3） | 不能当真正服务器填写 |
| `2001:db8::5` | 文档示例 IPv6 | 不能实际使用 |
| `127.0.0.1` | IPv4 loopback，本机 | 与 VPS 地址不同 |

私网范围包括 `10.0.0.0/8`、`172.16.0.0/12`、`192.168.0.0/16`。**Static（静态）**说的是一段时间内不变化；**Dedicated（独享）**描述是否与其他用户共享；**Datacenter/ISP/Residential**描述资源的归属、运营方式或服务商分类，彼此不能简单画等号。

### 实验 2：看 DNS 解析与 IPv4/IPv6

```powershell
Resolve-DnsName example.com
nslookup example.com
curl.exe -4 --noproxy "*" https://api.ipify.org
curl.exe -6 --noproxy "*" https://api64.ipify.org
```

- `Resolve-DnsName`/`nslookup` 查询 DNS。不同解析器及缓存可能给出不同回答。
- `curl.exe` 而非 PowerShell 旧别名 `curl`，明确使用 curl 程序；`--noproxy "*"` 禁用 curl 通过代理的配置（**不**绕过操作系统层的 VPN）。
- `-4` 限定 IPv4，`-6` 限定 IPv6。没有 IPv6 能力时 `-6` 失败正常；请记录“无 IPv6”，不要把失败当作漏洞。

**理解**：DNS 查询的实际目的地和站点内容传输的目的地通常不一样；使用 HTTPS 并不自动保证 DNS 查询不暴露。

## 3. TCP、UDP、端口、TLS 与 SSH

**TCP**：有序可靠字节流、握手、重传与拥塞控制；HTTPS 常用 TCP/443（HTTP/3 还可用 UDP/443）。**UDP**：传输数据报，不保证传输/顺序，WireGuard 通过 UDP 传输加密报文。**端口**：识别同一台机器上的不同网络服务。例如 SSH 常见 TCP/22；WireGuard 本教材使用 UDP/51820。不是“打开某个端口就自然更快”。

**TLS**：为应用通信提供认证、加密与完整性保护；HTTPS 是 HTTP 与 TLS 的常见组合。浏览器看到的 HTTPS 锁标识，不代表你完全匿名。**SSH**：远程登录协议，用于安全管理 VPS，默认基于 TCP；其密钥体系与 WireGuard 密钥不通用。

### 实验 3：观察连接

```powershell
Test-NetConnection example.com -Port 443
Get-NetTCPConnection | Select-Object -First 10
```

不要把 `Get-NetTCPConnection` 结果中的地址误认成“网站看到的出口 IP”——它主要反映本机 TCP 状态。

## 4. 路由、NAT 与转发（本项目核心）

电脑产生发往 `93.184.215.14` 的包时，系统依据路由表决定“下一跳”和“从哪张网卡发出去”。假设 Windows 的私网地址是 `192.168.1.10`，本地路由器会通过 **SNAT**（源网络地址转换）把其源地址转换为路由器的公网出口地址。对返回的数据，设备凭借 **conntrack**（连接跟踪）找到原始内网连接。

本教材 WireGuard 使用下面的路径：

```text
Windows 应用           VPN 内层包: src 10.66.66.2 → dst 网站IP
     │
     └─加密 UDP ──> VPS公网IP:51820
                       │ VPS解密：内层包仍然是 10.66.66.2 → 网站IP
                       │ IP Forwarding：允许内层包通过另一张网卡转发
                       │ SNAT/MASQUERADE：源改为 VPS 公网出口地址
                       ▼
                     网站服务器
                       │ 回包发向 VPS
                       ▼
               VPS conntrack 还原至 10.66.66.2，经 wg0 加密发回 Windows
```

**IP Forwarding** 是允许内核在不同网卡间转发，**NAT** 是修改数据包地址，两者并不相同。前者开了但没有后者，公网通常没有到 VPN 私网的回程路由；后者单独开了但不转发，也无效。**DNAT** 修改目的地址，常用于端口转发，本项目第一阶段不需要。

### 实验 4：先预测，不要先改服务器

在纸上写出下列阶段的源 IP：① Windows 内层 VPN 包；② VPS 发往网站的数据包；③ 网站所见来源。预期是 `10.66.66.2 → VPS 公网出口 IP → VPS 公网出口 IP`。注意若 VPS 处于供应商 NAT 后面，系统网卡地址不一定是最终公网出口；应通过外网观测确认。

## 5. VPN 与 HTTP/SOCKS 代理的本质区别

**VPN** 通常在 IP 网络层建立虚拟接口，按照路由将 IP 包封装、加密交付到远端；**HTTP 代理**通常由应用显式指示代理服务器发起 HTTP 请求或通过 CONNECT 建立隧道；**SOCKS5**可以为支持该协议的应用代理连接，但不意味着默认代理整台电脑所有协议。**系统代理**通常只是某些应用可读取的配置，而不是全系统网络层的默认路由。

| 技术 | 由谁决定使用 | 常见范围 | 重要限制 |
|---|---|---|---|
| WireGuard VPN | 系统路由+WireGuard | 可承载 IP 流量 | 需要正确路由、转发、DNS、IPv6 策略 |
| HTTP Proxy | 支持的应用 | 主要 HTTP/HTTPS | 其他协议可能不支持 |
| SOCKS5 | 支持 SOCKS 的应用 | TCP 连接常见 | UDP 能否工作取决于客户端/服务端支持 |
| 浏览器代理 | 浏览器 | 浏览器流量 | 其他软件不一定使用 |

**为什么 SOCKS5h 重要**：在 curl 中 `socks5://` 让 curl 本地解析目标域名，`socks5h://` 将目标主机名交给 SOCKS 代理解析；此区别与 DNS 路径有关，但不代表所有 DNS 请求被保护。

### 实验 5：理解“看似同一个浏览器，两个不同出口”

先不要购买或配置任何额外资源。思考：一个启用 WireGuard 的 Windows，其浏览器又配置了 HTTP 代理，会有几条独立设置影响出口？答案：至少两层——访问代理服务器的网络路由、以及代理服务器再访问网站的行为；浏览器网站可见来源通常是最后一跳代理的出口，而不是 VPS 的地址。

## 本篇验收与自测

- [ ] 能说明 IP、端口、TCP、UDP、DNS 各做什么。
- [ ] 能识别 Windows 默认路由与 IPv6 是否存在。
- [ ] 能画出 VPN 中“加密外层 UDP”与“被封装的内层 IP”的区别。
- [ ] 能解释为什么 IP Forwarding 与 NAT 必须分别考虑。

1. 问：`AllowedIPs=0.0.0.0/0` 是否覆盖 IPv6？答：**否**；IPv6 默认前缀是 `::/0`。
2. 问：HTTPS 已经加密，DNS 就肯定不会暴露吗？答：**否**；DNS 路径独立，需检查解析器及 DNS 请求走的网卡。
3. 问：启用 VPS 上的 VPN，网站一定看到 ISP 代理 IP？答：**否**；ISP 代理必须被明确接入请求路径。

**延伸官方资料（核验日：2026-10-30）**：
- Microsoft Windows VPN routing: https://learn.microsoft.com/en-us/windows/security/operating-system-security/network-security/vpn/vpn-routing
- Microsoft Test-NetConnection: https://learn.microsoft.com/en-us/powershell/module/nettcpip/test-netconnection?view=windowsserver2025-ps
- Cloudflare DNS 学习中心: https://www.cloudflare.com/learning/dns/what-is-dns/
- curl SOCKS proxy: https://everything.curl.dev/usingcurl/proxies/socks.html

---

<a id="part-2"></a>

# 第二篇｜审计你已经购买的 VPS 与静态 ISP 代理

> 目标：**不购买新服务、不公开任何凭据**，识别现有设备和服务能否组成美国/日本出口。只有对参数有了实测证据，才能选择适合的架构。

## 1. 先区分“控制面”和“数据面”

VPS 供应商控制台（控制面）用于查看实例状态、重装、救援控制台、快照、云防火墙；实例内的 Linux 系统（数据面）负责真正处理网络包。ISP 代理商面板可能给你服务器地址（host）、端口（port）、代理协议、账号密码或来源 IP 白名单、可用地区、带宽/并发限制。**代理服务器的 IP 不一定等于最终电商网站看到的 IP**，后者应通过实测确认。

请自行在供应商后台填写 **仅本地保存** 的资源审计表，不上传至 GitHub：

| 字段 | 如何查 | 风险 |
|---|---|---|
| VPS OS | 控制台/`cat /etc/os-release` | 对照 Ubuntu 与 Debian 命令 |
| VPS 地区和公网 IPv4 | 控制台、从 VPS 执行外网 IP 查询 | IP 所属地可能与 GeoIP 库不一致 |
| VPS 管理端口 | 面板 SSH 设置/`ss -lntp` | 操作防火墙前必须知道 |
| 网卡名称 | `ip route get 1.1.1.1` | `eth0` 只是示例，可能叫 `ens3` |
| 代理协议 | 服务商面板：HTTP/HTTPS/SOCKS5 | 决定 curl 参数 |
| 代理入口 host/port | 服务商面板 | 不代表最终出口 |
| 代理认证 | 用户密码/白名单 | 不能进入命令历史或仓库 |
| 美国/日本可用情况 | 商家区域说明 + 外网验证 | 别凭 IP 名称臆测 |
| 代理带宽、流量、并发 | 套餐/条款 | 决定可维护性 |

**静态 != 独享 != ISP/住宅**。静态指地址较稳定，独享说明资源是否由多人共享，ISP/住宅分类与地址分配和运营主体相关；商家的营销标签并不足以证明网络性质。核对平台与代理商允许的实际业务用途。

## 2. 三个真实路径，三种不同的结果

```text
A   Windows ── WireGuard ── VPS ── 网站
                               网站通常看到 VPS 出口 IP

B   Windows ── 应用代理设置 ── ISP Proxy ── 网站
                                               网站通常看到 ISP 代理出口 IP

C   Windows ── WireGuard ── VPS ── ISP Proxy ── 网站
                        ↑             ↑
                   VPN 负责 IP 路径   应用须明确使用上游代理
```

C 的要点：**“先开 VPN 再在支持的应用里设置 ISP 代理”是可以实验验证的一种 C**。应用的 TCP 连接首先走 VPN 到达代理入口；代理再与网站建立连接。默认 WireGuard **不会**自动把全部 VPN 流量转换为 HTTP/SOCKS 流量。如需透明代理所有应用，需要额外软件/规则，并处理 TCP、UDP、DNS、DNS-over-HTTPS、失败时回落、IPv6 等复杂情形；本教程不把它当初学者必做项目。

## 3. 实验：三次查出口 IP

**Windows PowerShell，实验前**：

```powershell
curl.exe -4 --noproxy "*" https://api.ipify.org
```

记录为 `WINDOWS_DIRECT_IP`；这不包含浏览器内置代理的行为。打开 WireGuard 并成功配置后重复，记录为 `VPS_EGRESS_IP`。若两者相同，不代表 VPN 一定坏了（存在同出口网络等特殊情况），需要和路由及服务器抓包交叉确认。

**在 VPS SSH 会话中**：

```bash
cat /etc/os-release
ip -br address
ip route get 1.1.1.1
curl -4 --noproxy '*' https://api.ipify.org
sudo ss -lntup
```

`ip route get` 会显示下一跳与出接口，`ss` 看当前监听端口。若 VPS 尚未安装 curl，可先运行 `command -v curl`，只在 Ubuntu/Debian 上根据后续安装章节安装。

**代理测试（有密码认证时）**：不要把密码直接写进命令行。首先识别服务商是 HTTP 还是 SOCKS5。接下来将 `PROXY_HOST`、`PROXY_PORT` 改为你本地已知的真实值。工具会提示输入密码（按代理认证方式而定）：

```powershell
# 仅适用于 HTTP 代理；若是 IP 白名单认证，通常不需 --proxy-user
curl.exe -4 --proxy http://PROXY_HOST:PROXY_PORT --proxy-user USERNAME https://api.ipify.org

# 若服务商实际提供 SOCKS5 协议；域名由代理端解析
curl.exe -4 --proxy socks5h://PROXY_HOST:PROXY_PORT --proxy-user USERNAME https://api.ipify.org
```

若代理不需要用户密码（例如 IP 白名单），去掉 `--proxy-user USERNAME`。HTTP 代理通常使用 CONNECT 访问 HTTPS；若不支持认证或 CONNECT，按商家说明检查。`curl.exe` 会报告 `407 Proxy Authentication Required`、超时、连接失败等可供定位的错误；不要把含认证信息的调试日志公开。

> 特别提醒：如果代理采取**来源 IP 白名单**，在 Windows 直连和经 VPS 访问时，代理所看到的来源 IP 不同，白名单需要匹配实际进入代理的来源。不要把密码或真实代理地址发给任何聊天机器人。

**验证格式**（本地笔记，推送 GitHub 时要脱敏）：

```text
Direct Windows IPv4: [仅本地填写]
VPS egress IPv4: [仅本地填写]
ISP proxy egress IPv4: [仅本地填写]
Proxy type: HTTP / SOCKS5 / unknown
Available exit: US [verified/unverified] | JP [verified/unverified]
```

## 4. 如何决定下一步

- 如果 VPS 是 Ubuntu 24.04/26.04 LTS，继续第三、四篇；**24.04** 的示范命令更便于统一核对，26.04 需先在新系统逐条确认。
- 如果 VPS 是 Debian，先学原理，但不要不加核对照搬 UFW 的专用文件路径/规则。
- 如果 VPS 已运行网站、其他 VPN、防火墙或容器服务：**不要覆盖现有规则**；先做快照和规则审计，并选择隔离的实验实例/测试窗口。
- 如果只有一个美国出口且没有日本代理，暂时只完成美国路径。日本出口留作设计和验证任务，不凭空声称已实现。

## 本篇验收与自测

- [ ] 明确现有 VPS 的 OS、SSH 端口、默认出接口和出口 IP。
- [ ] 明确 ISP 代理是 HTTP、HTTPS 还是 SOCKS5，以及认证方式。
- [ ] 三个路径的实际 IP 分别独立记录；某项不能测试就标“待验证”。

1. 问：查到 `PROXY_HOST` 是美国 IP，网站看到的必是这个地址吗？答：不必然，代理入口和出口可能分离。
2. 问：没有配置上游代理的 WireGuard 默认使用 ISP 代理吗？答：不会。
3. 问：为什么要在 **Windows** 和 **VPS** 各查一次 IP？答：对比客户端路径、服务器出口，检查 VPN 是否改变出口，排除仅本机命令使用代理的干扰。

**参考（核验日：2026-10-30）**：
- curl 代理协议选项: https://curl.se/docs/manpage.html
- curl SOCKS5h 与 DNS: https://everything.curl.dev/usingcurl/proxies/socks.html
- Ubuntu 发行版支持周期: https://ubuntu.com/about/release-cycle

---

<a id="part-3"></a>

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

---

<a id="part-4"></a>

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

---

<a id="part-5"></a>

# 第五篇｜接入现有静态 ISP 代理：三种路径逐一验证

> 本篇目标不是“伪装身份”，而是理解代理作为应用层中继的行为，验证已获得授权的业务网络出口。没有代理商明确提供的协议和认证参数，不猜测端口/协议，更不把任何凭据交给第三方。

## 1. 先理解 IP 和代理地址的区别

你的代理商可能提供 `proxy.company.tld:port`（只是演示格式）、HTTP 代理或 SOCKS5 代理。这个是**代理入口**，访问最终目标站点的流量由代理的另一端发出，网站看到的**代理出口**未必等于入口地址。VPS 则是一台你可通过 SSH 管理的云服务器，有自己的出入口网络。把两者配合，不会自动将 VPS 的公网出口变为“住宅 IP”。

### 三种路径及各自适用范围

```text
A. 应用 → Windows VPN → VPS NAT → 目标网站
   终点一般看到 VPS 出口 IP（可作为基础网络工程实验）

B. 支持代理的应用 → ISP Proxy → 目标网站
   终点一般看到 ISP 代理出口 IP（代理连接采用电脑当前网络路径）

C. 支持代理的应用 → Windows WireGuard → VPS → ISP Proxy → 目标网站
   终点一般看到 ISP 代理出口 IP；连接代理入口的 TCP 先经过 VPS
```

C 的第一阶段实现不需要复杂的“透明代理服务器”，而是将 Windows 的 WireGuard 设置为全 IPv4 隧道，**再在特定应用（本章用 curl）里配置代理**。该模式只保证 **这个明确配置代理的应用请求**，不保证其他所有应用都走 ISP 代理。想让整个系统自动使用 ISP 代理是另一个高级问题，需额外的软件和访问控制。

## 2. 代理协议、认证和 DNS

- **HTTP 代理**：客户端通常将 HTTP 请求发给代理；访问 HTTPS 网站一般利用 CONNECT 建立 TCP 通道，再由浏览器与目标站点进行 TLS 交互。
- **HTTPS 代理**：指客户端到代理的连接本身使用 TLS，和“通过 HTTP 代理访问 HTTPS 目标”不是同一个概念。
- **SOCKS5**：泛用的代理协议；curl 的 `socks5://` 默认由本机解析目标域名，`socks5h://` 则将主机名送到代理端解析。SOCKS5 协议可以定义 UDP ASSOCIATE，但特定应用、代理商可能不支持；不要假设你的所有 UDP 都会经 SOCKS5。
- **IP 白名单认证**：代理商检查连接代理入口时的来源公网 IP；B 和 C 路径来源可能不同。
- **用户名/密码认证**：代理商提供账号与口令；尽量通过交互输入而非在脚本、命令行参数、浏览器地址栏中明文保存。

**重要的泄漏细节**：SOCKS5h 能避免 curl 为**目标网站**本地解析域名，不代表访问 `PROXY_HOST` 本身不需要 DNS，也不代表其他应用的 DNS 自动进入代理。WireGuard DNS 的配置同样需要独立验证。

## 3. 实验 A：Windows → VPS → 网站

在第四篇 WireGuard 全 IPv4 隧道开启的前提下，PowerShell 中运行：

```powershell
curl.exe -4 --noproxy "*" https://api.ipify.org
route print -4
```

预期 IP 与 VPS 对外地址相符。保持记录：

```text
A: IP=[只本地存]    IPv4 route=[WireGuard]    proxy=[none]
```

这一步不使用任何 ISP 代理；它是后面比较的对照组。

## 4. 实验 B：Windows → ISP Proxy → 网站

先关闭 WireGuard（仅在安全实验阶段；不应用于已要求固定出口的业务）。使用 **你从代理商控制台确认的协议**，选择下列一个：

**B1：HTTP 代理**：

```powershell
curl.exe -4 -x http://PROXY_HOST:PROXY_PORT -U USERNAME https://api.ipify.org
```

**B2：SOCKS5 代理，代理端解析域名**：

```powershell
curl.exe -4 -x socks5h://PROXY_HOST:PROXY_PORT -U USERNAME https://api.ipify.org
```

**B3：使用来源 IP 白名单**：移除 `-U USERNAME`，并确保商家白名单包括 Windows 此刻真正的对外源 IP。`-U USERNAME` 如有密码认证会提示输入口令（部分 curl 构建/认证方式不同，以错误信息和官方说明为准）。若实际代理方案通过其他方式认证，请遵循商家官方说明，**不要**将密码放进共享的 `.ps1` 或上传仓库。

记下 `B: egress=[仅本地存]`。若返回 HTTP 407，多半是代理认证失败；若连接超时，先查服务器、端口、白名单、商家可用状态，不要直接归咎于 HTTPS/TLS。

## 5. 实验 C：Windows → WireGuard → VPS → ISP Proxy → 网站

1. 重新激活第四篇的 WireGuard IPv4 隧道。
2. 确认 `curl.exe -4 --noproxy "*" https://api.ipify.org` 仍为 VPS 出口（对照组 A）。
3. 再执行 B1 或 B2 的 **显式代理**命令。
4. 验证此请求显示的出口为 ISP 代理出口（对照组 B）。

如果使用来源 IP 白名单，C 模式下上游代理看到的来源 IP 通常是 VPS 的出口 IP，而不是 Windows 本地 ISP 的 IP。请根据**服务商允许的合法使用方式**处理白名单，不要把白名单规则设计成绕过平台限制的工具。

**进一步验证代理连接确实经 VPS**（只在已授权的 VPS 上，仅供短期诊断）：

在 VPS 执行：

```bash
# 先用 getent 查出代理入口的地址（只读，不打印密码）
getent ahostsv4 PROXY_HOST

# 将输出中查得的入口 IPv4 替代 PROXY_ENTRY_IPV4
sudo tcpdump -ni WAN_IF host PROXY_ENTRY_IPV4 and tcp port PROXY_PORT
```

若尚未安装 `tcpdump`，在 Ubuntu 上可选择 `sudo apt install tcpdump`。确认把 `WAN_IF` 替换为 `ip route get` 得出的网卡名。再次执行 Windows curl 命令，可看到 VPS 与代理入口的 TCP 流量。**抓包可能包含业务敏感信息**：仅抓你自己控制的流量，避免在实际业务会话中抓取，结束后按 `Ctrl+C` 停止，不上传 pcap 或含真实地址的截图。

还可在 Windows 执行 `route print -4` 和 `Get-NetRoute -AddressFamily IPv4`，检查到代理入口的路由是否属于 WireGuard 路径。若连接代理使用的是 IPv6，而 VPN 只覆盖 IPv4，则 C 的路径假设可能不成立；实验时强制 curl `-4` 是为了获得明确可复现的 IPv4 样本。

## 6. 严格区别“应用代理”“Windows 系统代理”“VPN”

浏览器可能遵守 Windows 系统代理，也可能有独立代理设置；命令行 `curl.exe` 可显式指定代理；某些游戏、客户端、后台服务、QUIC/UDP 或应用内 DNS 不遵守系统代理。**不要用“我的浏览器成功走代理”推出“整个电脑的所有流量都走同一个代理”。**

在公司业务中，优先为已获平台授权的办公应用使用清晰、可审计的配置；不建议在零基础阶段使用来源不明的 TUN/透明代理一键脚本，它可能影响防火墙、DNS、路由，并使失败时流量意外回落。

## 7. 如果代理出口地区不符合预期

先分清四个不同概念：供应商标称地区、代理入口所在地区、出口公网地址、网站自己的 GeoIP 判断。用至少两个合法外网查询来源交叉核验。GeoIP 数据库可能存在滞后或误判，因此不可宣称换一个地区标签就自动满足平台所在地要求。应核对平台对经营主体、地区、税务/KYC、支付和店铺运营的政策。

## 8. 排查表

| 错误 | 先查什么 | 可能解释 |
|---|---|---|
| `407 Proxy Authentication Required` | 认证方式、用户和口令、是否需要白名单 | 代理拒绝访问 |
| `Could not resolve proxy` | 代理 host 拼写及 DNS | 解析入口失败 |
| `Connection refused` | 代理 host/port、服务器工作状态 | 端口没有接受连接 |
| `Connection timed out` | 网络路径、防火墙、商家网络状态 | 连接不能建立 |
| 经代理后显示 VPS IP | curl 是否实际启用了代理、`NO_PROXY` 规则、代理出站分配 | 代理配置未生效，或上游出口与 VPS 重合 |
| C 只在本地能用，经 VPS 不能用 | 商家来源 IP 白名单或网络许可 | C 路径与 B 源 IP 不同 |
| 浏览器能用，另一应用不能 | 应用是否支持代理/UDP/QUIC | 不能用浏览器成功证明全系统成功 |

## 9. 自测与验收

- [ ] 你能向别人解释 A/B/C 的网络层与应用层分工。
- [ ] 在脱敏实验笔记中写出三种路径实测结果、协议、日期和验证方法。
- [ ] 你知道 curl 的 `socks5h://` 与 `socks5://` 关于 DNS 的区别。
- [ ] 没把代理秘密写进命令历史、GitHub 或测试报告。

1. 问：Windows 开启了 WireGuard，curl 又使用 ISP HTTP 代理，网站更可能看到哪一个 IP？答：ISP 代理最后实际出口 IP。
2. 问：上述结论是否可推广到 Windows 的所有应用？答：不能，只能推广到确实使用此代理路径的应用/协议。
3. 问：为什么 C 的 IP 白名单可能不同于 B？答：连接代理入口的实际来源公网 IP 从 Windows 出口变为 VPS 出口。

**官方参考（核验日：2026-10-30）**：
- curl 代理协议: https://curl.se/docs/manpage.html
- curl SOCKS5(h): https://everything.curl.dev/usingcurl/proxies/socks.html
- curl HTTP Proxy: https://everything.curl.dev/usingcurl/proxies/http.html
- Microsoft VPN routing: https://learn.microsoft.com/en-us/windows/security/operating-system-security/network-security/vpn/vpn-routing

---

<a id="part-6"></a>

# 第六篇｜美国 / 日本多出口：从单节点到策略路由

> **不要假设你已经拥有两个地区的出口。** 这是一章架构设计与可验证的应用级切换实验，不引导绕过电商平台地理、身份或账号规则。

## 1. 业务需求先转化成网络需求

真实目标可能是：访问美国官方运营资源时使用获得授权的美国办公出口；访问日本测试/官方资源时使用日本出口。关键属性分别是 **出口 IP 和所在地是否实测**、**允许的使用范围**、**链路可用性**、**连接失败时是否阻断**、**应用是否能明确选择出口**。IP 地区只是网络属性，不能代替合规身份或经营资质。

## 2. 三类架构

```text
方案 1：单 VPS + 两个上游代理（适合明确支持代理的应用）
Windows → WireGuard → VPS → US Proxy → US 授权目的站点
                          └─→ JP Proxy → JP 授权目的站点

方案 2：美国 VPS + 日本 VPS（适合需要不同 IP 网关的实验）
Windows ─WG-US→ US VPS → 网站
       └WG-JP→ JP VPS → 网站

方案 3：专门的企业网络网关（高级）
Windows/办公终端 → 管理网关 → 按策略识别目的流量 → 合法出口
```

**方案 1**：无需两个 VPS，但必须真的拥有两个可用地区的上游代理；应用本身需要能指定代理。**方案 2**：每条 VPN 配置独立密钥和不同内网段（例如 US 使用 `10.66.66.0/24`，JP 使用 `10.67.67.0/24`），不能把不同隧道同时设为默认路由而不规划优先级；切换时还需验证 DNS、IPv6 和 Kill Switch。**方案 3**：涉及策略路由、网络命名空间、透明代理或专用网关，复杂度显著提升，不是基础项目的必选项。

## 3. 应用级切换的安全实验

若你已经合法持有 US、JP 两个 HTTP 或 SOCKS5 代理，分别在 PowerShell 中运行（替换对应入口地址与认证参数）：

```powershell
# US 代理示例：使用已确认的 HTTP 代理
curl.exe -4 -x http://US_PROXY_HOST:US_PROXY_PORT -U US_USERNAME https://api.ipify.org

# JP 代理示例：使用已确认的 SOCKS5 代理
curl.exe -4 -x socks5h://JP_PROXY_HOST:JP_PROXY_PORT -U JP_USERNAME https://api.ipify.org
```

**必须按实际协议替换**，不能因为地区是日本就默认 SOCKS5。正确验证的内容是网络出口与供应商分配一致、请求确实成功、目标为授权测试站点。若仅有一个国家的资源，另一项填写 `not available / not tested`。

## 4. 逐渐深入：路由表、最长前缀、策略路由

普通路由根据目标 IP 匹配路由前缀；**最长前缀优先**。多个相同长度的默认路由则依赖 metric 和操作系统处理方式。`ip rule` 可在 Linux 中根据源地址、标记等选择不同路由表（Policy Routing），不意味着普通 HTTP 代理可以直接成为 IP 层下一跳。

只读实验（在 VPS）：

```bash
ip route show
ip rule show
ip route show table main
```

Windows：

```powershell
route print -4
Get-NetRoute -AddressFamily IPv4 | Sort-Object DestinationPrefix
```

**不要**在远程 VPS 上随意执行 `ip route replace default ...` 练习多出口，否则可能立刻切断 SSH。需要高级路由实验时应使用隔离虚拟机/额外网卡或受控网络命名空间，并配置可达的回滚控制台。

## 5. 切换、回退与监控思路

切换前先记录原出口；切换后连续测试 IPv4 出口、可用 DNS、IPv6、应用连接（并观察是否从错误国家回退）；故障时应优先中断高要求业务流量，而不是自动退回到本地 IP。多出口健康检查要区分“代理入口 TCP 可连接”“真实代理请求成功”“结果出口 IP 符合预期”三层。

## 本篇验收与自测

- [ ] 画出自己的目标架构，并标记美国/日本资源是否真实存在。
- [ ] 独立运行出口测试并记录两个地区的结果（缺少资源明确标注）。
- [ ] 能解释应用代理与 Linux Policy Routing 是不同层次的机制。

1. 问：一个 VPS 公网 IP 能否凭空变成两个不同国家的 IP？答：不能。需要真实可用的目标地区网络出口。
2. 问：把代理地址写进 `ip route` 默认网关是否就等于通过 HTTP 代理出网？答：不是，HTTP 代理不是普通的三层路由下一跳。
3. 问：跨国节点切换应只看 IP 查询成功吗？答：不够，还需要 DNS、IPv6、故障回退与应用真实行为验证。

**官方参考（核验日：2026-10-30）**：
- Ubuntu WireGuard default gateway 与路由说明: https://ubuntu.com/server/docs/wireguard-vpn-defaultgw/
- Microsoft VPN routing: https://learn.microsoft.com/en-us/windows/security/operating-system-security/network-security/vpn/vpn-routing
- curl 代理选项: https://curl.se/docs/manpage.html

---

<a id="part-7"></a>

# 第七篇｜可靠性、安全、IPv6 与防泄漏

> 目标：学会从“VPN 连通”升级到“知道哪些流量会被允许或阻断”。防泄漏不是一个开关的宣传词，而是具体系统配置、实际路由与反例测试共同证明的状态。**本篇所有功能必须在实验流量上验证，未经验证不用于固定出口的业务操作。**

## 1. Kill Switch：断线时是否允许直连

**直观类比**：原本你只允许货车走公司指定的出口，一旦该通道故障，你希望车辆停止，而不是自动驶入私人出口。

**技术定义**：Kill Switch 是一组网络防火墙/路由控制策略，控制 VPN 不可用时是否允许受保护的流量通过其他网卡直连。只改默认路由可能无法实现真正的 fail-closed（失败时禁止外发）。

**重要的 Windows 事实**：WireGuard for Windows 的官方说明规定：当一个隧道只有一个 Peer 且其 `AllowedIPs` 含 `/0` 时，会应用所谓 **kill-switch 防火墙规则**，允许隧道自身、部分必要网络协议及合规 DNS，阻断其余非隧道流量。具体是否启用、配置 UI 和版本应按当前 Windows 官方客户端核验，不能把这个行为推广到其他第三方客户端。即使有断线阻断，**用户手动停用 VPN 后的行为**也不能假定依然受保护；这属于需额外审计的系统层强制策略。

官方实现说明：https://git.zx2c4.com/wireguard-windows/about/docs/netquirk.md

### 实验 1：验证故障而非猜测

1. 在**非业务测试时段**正常 Activate WireGuard；记录 `curl.exe -4 --noproxy "*" https://api.ipify.org` 和路由。
2. 确认当前客户端是否实际应用阻断规则，不要仅凭 UI 按钮文本作推断。
3. 可在控制台上临时阻断服务端的 WireGuard UDP 入站端口（仅在你知道安全回滚路径、且不影响他人时）模拟隧道失效；更安全的做法是在**本机受控测试隧道**修改为不可达 Endpoint，测试完成立刻恢复，不要触碰生产 VPN。
4. 观察出口查询：应**失败/超时**而不是悄悄返回本地出口 IP。恢复后再次验证 VPS 出口。
5. 单独测试“主动 Deactivate”是什么行为，标注为不同于“隧道意外断连”的实验。

> [!WARNING]
> 仅用于受控测试。不要在进行真实跨境电商交易、平台后台操作或团队共用连接时测试断线与回落。并非每个 Windows VPN/代理客户端都具备同样的阻断语义。

## 2. DNS 防泄漏

DNS（Domain Name System）把域名转换为地址。查询 DNS 与网站 HTTPS 访问可能走不同网络；Windows 存在多网络适配器、浏览器可能启用 DoH，代理又可能自行解析域名。

**先看本机设置**（Windows）：

```powershell
Get-DnsClientServerAddress
Get-NetIPInterface -AddressFamily IPv4 | Sort-Object InterfaceMetric
Resolve-DnsName example.com
```

**再判断实际 DNS 路径**：
- WireGuard 配置中的 `DNS = 1.1.1.1` 表示客户端向接口设置的目标解析器，不等于自动保证所有应用都使用它。
- 仅对特定 DNS 服务器执行 `nslookup example.com 1.1.1.1` 是**手动指定解析器的功能测试**，不能证明系统、浏览器所有查询都用它。
- DNS 查询是否经过 WireGuard，需要结合 Windows 路由、客户端规则与实际抓包观察；浏览器 DoH 需另外审计，不应拿一次 `nslookup` 的结果当成全面无泄漏证据。
- 代理的 `socks5h://` 负责让该应用的**目标域名**由 SOCKS 代理解析，不意味着系统其他 DNS 请求被代理。

**验收**：在激活 VPN、断线与停用时分别记录 DNS 使用的接口/服务。若不能确认，就标“DNS 路径待验证”，而不是写“100% 无泄漏”。

## 3. IPv6：为什么 IPv4 隧道不等于全流量隧道

`AllowedIPs = 0.0.0.0/0` 只覆盖 IPv4，IPv6 全流量前缀是 `::/0`。若 IPv6 不在受保护的隧道路由中且系统缺乏防火墙阻断，就可能发生 IPv6 直连。Windows 官方 WireGuard 在特定 `/0` 配置下具有阻断逻辑，但不能将其泛化到其他工具。

**检查**：

```powershell
ipconfig /all
route print -6
curl.exe -4 --noproxy "*" https://api.ipify.org
curl.exe -6 --noproxy "*" https://api64.ipify.org
```

对于没有可用 IPv6 出口的 **IPv4-only 教学服务器**，推荐学习路线是：明确标记**仅允许经验证的 IPv4 流量**、使用经过验证的客户端阻断规则保证 IPv6 不从本地路径漏出，再观察 IPv6 的请求失败是否符合预期。不要在不知道服务端 IPv6 地址、IPv6 路由和防火墙时照搬 `::/0`，因为可能造成不可达、误判或非预期直连。

**进阶 IPv6 全隧道**：必须在服务端有合法可路由 IPv6 前缀或受支持的 IPv6 出站机制；为 wg0 分配 IPv6 地址、配置 IPv6 forwarding、正确的 IPv6 路由/防火墙、DNS AAAA 测试以及公网 IPv6 出口验证。IPv6 通常优先使用真实路由而不是照搬 IPv4 NAT，具体依赖 VPS 服务商的前缀分配方式。本教材不虚构每个 VPS 都有可用 IPv6，也不提供未经环境验证的通用 IPv6 配置。

## 4. 分流（Split Tunnel）与全隧道（Full/Force Tunnel）

- **全隧道**：系统路由让目标流量（例如全部 IPv4）经 VPN 转发。WireGuard 客户端 `[Peer] AllowedIPs = 0.0.0.0/0` 常用于此场景。
- **分流**：仅配置指定网段经 VPN，例如 `10.66.66.0/24`，其他目标经本地默认路由。这个配置便于管理专用内网，但**不保证外部业务站点使用 VPS 出口**。
- **指定应用走 VPN**：需要操作系统、应用或专业网络策略支持，并非仅用某个 `AllowedIPs` 字段就能完美按进程分流。站点域名映射成的 IP 还可能变动，简单静态路由不是稳定的域名分流替代品。

### 实验 2：只读比较路由

先记录 Windows 未开隧道的 `route print -4`；激活 WireGuard 后再查看一次。比较默认 IPv4 路由的接口与 metric，并说明为何 `/0` 会影响普通网站路径。**不要在远程 VPS 上直接覆盖默认路由做实验**。

## 5. 网络速度：延迟、丢包、吞吐与 MTU

**延迟（latency）** 是往返时延 RTT；**丢包（packet loss）** 是发送的数据未能成功到达；**吞吐（throughput）** 是单位时间有效数据量；**带宽（bandwidth）** 是链路可承载量。这些指标并非同一个概念。

**MTU（最大传输单元）**：链路一次可承载的最大 IP 包大小。WireGuard 会额外增加封装和加密开销，因此隧道接口有效 MTU 通常小于外层承载网络。常见网络中 WireGuard 默认 MTU 约 1420，但实际应依路径/IPv4/IPv6、云网络和封装链路判断。

**PMTUD**：路径 MTU 发现；若必要 ICMP 被丢弃，有时表现为“小请求成功，大请求卡住”。**MSS** 是 TCP 分段最大数据负载大小；它与 MTU 有关但不相同。

Windows 诊断（ICMP 允许时才有参考价值）：

```powershell
ping 1.1.1.1 -n 5
tracert -4 1.1.1.1
ping 1.1.1.1 -f -l 1372
```

`-f` 是 IPv4 禁止分片；`-l 1372` 是 Windows ping 的 ICMP payload 长度，并不是直接“把 MTU 设成 1372”。如回显被服务器过滤，不能从失败反推出真实 MTU。出现卡顿先排查 IPv6、DNS、路由、上游代理超时、丢包，再考虑逐步测量 MTU，而不是盲目设定单一数值。

## 6. 自动重连与监控

WireGuard 的 `PersistentKeepalive=25` 用来维护 NAT 映射，**不是**高可用负载均衡。自动重连分为：操作系统恢复网卡、WireGuard 隧道重新握手、上游代理服务恢复、应用连接重试；每层都可能失败。

推荐监控三项，不应只监控某个域名能否 ping 通：

1. **隧道健康**：`sudo wg show` 的最新握手、流量计数。
2. **外网功能**：直连（无应用代理）查询 VPS 出口 IP。
3. **代理功能**：代理请求成功并返回预期 ISP 出口 IP（不得在公开日志保存代理凭据）。

VPS 只读检查：

```bash
sudo wg show
sudo systemctl status wg-quick@wg0 --no-pager
sudo journalctl -u wg-quick@wg0 -n 30 --no-pager
free -h
df -h
```

仓库 `scripts/network-check.ps1` 是 Windows 基础只读检查样例。它仅观测网络、可选公网 IP，不会修改路由、防火墙或代理；**一次成功不代表长期稳定**。部署监控前先设计合理频率和日志脱敏规则。

## 7. 备份与安全维护

- VPS 配置改动前保留供应商快照；快照中**可能包含私钥**，应放在私有、加密且访问控制严格的存储空间。
- 定期更新受支持的软件与操作系统，检查重启和维护窗口。绝不要把真实 `wg0.conf`、`server.key`、代理凭据放在 GitHub 仓库。
- 设备遗失或私钥泄露时：撤销对应 Peer 的公钥、重新生成密钥、重新部署受影响的设备；不能靠“改文件名”解决。
- 监控日志记录时间、目标服务健康、脱敏状态即可；不保存店铺 Cookie、认证令牌、客户数据。
- 若高可用有严格要求，需要正式的主备、证书/密钥管理和网络审计，而非本教材的单 VPS 示例。

## 本篇验收与自测

- [ ] 已完成 IPv4/IPv6 双栈出站测试，记录 VPN 开启/故障/关闭三种状态。
- [ ] DNS 测试不仅有结果，而且解释了其覆盖范围和限制。
- [ ] 能在 VPS 查看 WireGuard 最新握手与服务日志。
- [ ] 能说明分流、Kill Switch 与代理是三个不同概念。

1. 问：`socks5h://` 可以保证整个 Windows 不发生 DNS 泄漏吗？答：不能，只约束配置了该代理的应用请求的目标域名解析方式。
2. 问：Keepalive 25 秒是否等于掉线时阻断本地出口？答：不是；一个维护 NAT 映射，一个由防火墙/路由约束流量。
3. 问：仅 `curl -4` 返回 VPS IP 就证明双栈全隧道没有泄漏？答：不能，还需 IPv6、DNS、应用和断线行为验证。

**官方参考（核验日：2026-10-30）**：
- WireGuard for Windows Kill-switch 描述: https://git.zx2c4.com/wireguard-windows/about/docs/netquirk.md
- Ubuntu 全隧道与 DNS: https://ubuntu.com/server/docs/wireguard-vpn-defaultgw/
- WireGuard Keepalive: https://www.wireguard.com/quickstart/
- Microsoft VPN routing: https://learn.microsoft.com/en-us/windows/security/operating-system-security/network-security/vpn/vpn-routing

---

<a id="part-8"></a>

# 第八篇｜故障诊断实验与初级网络工程方法

> 最重要的技能不是记住命令，而是**按照数据包经过的链路，从一个能够观测到的事实定位故障点**。所有实验请在自有、授权且不承载真实电商交易的环境运行。生产环境仅执行只读检查和经过批准的修复操作。

## 1. 一套通用的六层检查顺序

```text
应用/网站请求失败
  ├─ L1：本地网卡与网络？ipconfig、Windows 默认路由
  ├─ L2：VPN 加密通道？VPS sudo wg show（latest handshake）
  ├─ L3：内层 IP 可达？10.66.66.1 与 AllowedIPs
  ├─ L4：VPS 是否转发+NAT？sysctl、UFW route、MASQUERADE 计数
  ├─ L5：DNS 与 IPv4/IPv6？Resolve-DnsName、curl -4/-6
  └─ L6：应用代理？代理类型、认证、CONNECT、出口 IP
```

诊断时不要同时修改三项参数。每次只改一项，记录“变更前结果—变更—变更后结果—是否回滚”，这样才能得出因果性结论。

## 2. 十个典型故障实验

### 案例 A：客户端完全没有握手

**现象**：WireGuard Windows 已激活，但 VPS `sudo wg show` 没有 `latest handshake`。

**检查**：VPS `sudo ss -lunp | grep 51820` 是否监听；云安全组是否允许 UDP/51820；Windows 的 `Endpoint` 是否为 VPS 可达地址；服务端/客户端的 Peer 公钥是否一一匹配。**修复**：逐项更正一处，再启用测试。`wg show` 看到最近握手并且流量计数变化，才证明握手恢复。

### 案例 B：有握手，但是 `10.66.66.1` 不可达

**现象**：有握手，但内层 IP 不能通信。

**检查**：Windows `Address` 和服务端 Peer `AllowedIPs`；VPS `ip -br addr show wg0` 与 `sudo wg show`；Windows `route print -4`。**修复**：确保 Windows 地址 `10.66.66.2/32`、VPS `wg0=10.66.66.1/24`、服务端对应 Peer 是 `10.66.66.2/32`。**验证**：观察响应和服务端计数，不完全依赖 ping（可能被防火墙过滤）。

### 案例 C：VPN 内网通，但所有外网连接失败

**现象**：能访问 `10.66.66.1`，但 `curl -4 https://api.ipify.org` 超时。

**检查**：

```bash
sysctl net.ipv4.ip_forward
ip route get 1.1.1.1
sudo ufw status verbose
sudo iptables -t nat -nvL POSTROUTING
```

**解释**：`ip_forward` 是否为 1？UFW 是否允许 wg0→WAN_IF 转发？NAT 计数器随 Windows 访问增加吗？VPS 自己访问外网是否正常？**修复**：针对缺失的转发/NAT 精确修复，不要清空防火墙。**验证**：Windows 出口 IP 变为 VPS 出口。

### 案例 D：可以访问 IP，但域名访问失败

**检查**：Windows `Resolve-DnsName example.com`、`Get-DnsClientServerAddress`、`curl.exe -4 --noproxy "*" https://api.ipify.org`。若 IP 查询成功而解析失败，优先检查 DNS 服务器可达性和客户端解析配置。**验证**：已授权域名可以解析并加载；需注意解析正常不保证网站业务本身正常。

### 案例 E：IPv6 意外从本地出口

**检查**：`route print -6`、`curl.exe -6 --noproxy "*" https://api64.ipify.org`，结合 WireGuard Windows kill switch 状态。**修复方向**：受控环境中使用已经核验的 IPv6 阻断/双栈 VPN 路由，不要盲目复制 `::/0` 及猜测防火墙规则。**验证**：业务要求阻断时 IPv6 查询失败；允许双栈时查询返回经过批准的出口 IPv6。

### 案例 F：代理请求返回 407

**检查**：协议 HTTP/HTTPS/SOCKS5 是否选对、用户名与认证方式、是否需要来源 IP 白名单、C 模式下是否已把来源切换到 VPS。**修复**：在服务商控制台安全更新/核对授权参数，重测同一条请求。**验证**：HTTPS 目标返回成功，且出口符合预期。

### 案例 G：VPS IP 与 ISP IP 不一致

这不一定是故障：A 路径返回 VPS，B/C 路径通常返回代理出口。先用三条不同的 curl 测试固定路径，再看是否发生应用代理未生效、`NO_PROXY` 例外、IPv6 直连或代理商出口变化。

### 案例 H：某个浏览器能用，但工作软件不能用

先查该软件是否实际支持 HTTP/SOCKS 代理、是否使用独立 DNS、UDP/QUIC 或固有 TLS 策略。**修复方向**：优先使用该软件官方支持的网络设置；不以“强制所有流量进代理”作为唯一方案。**验证**：在授权测试目标下观察软件自己的连接结果。

### 案例 I：建立连接后部分大页面卡顿

依序看 IPv6、DNS、MTU、代理超时、VPS CPU 和服务商线路。`ping` 失败可能只是 ICMP 被限制；`tracert` 显示 `*` 也不等于链路断开。不要一开始就把 MTU 随意改成 1280。

### 案例 J：修改 UFW 后 SSH 断开

**优先使用 VPS 供应商的独立 Console**。确认 SSH 实际监听端口和云安全组，然后恢复此前备份的 UFW 配置/规则。不要对不可达服务器反复提交未知命令，不要通过关闭所有安全机制作为长期解决方案。恢复后制定“第二 SSH 会话—测试—变更—验证—回滚”的标准维护程序。

## 3. 记录证据而不是记录秘密

每次故障记录：时间、客户端系统版本、VPS 系统版本、路径 A/B/C、已测试的命令、脱敏的日志、预期行为、实际行为、单次修改与结果。**不要记录**原始 `wg0.conf`、私钥、代理口令、平台 Cookie、支付数据、完整客户 IP 清单。

参考模板在 `troubleshooting/incident-template.md`。

## 4. 初级工程师验收挑战

1. 不看答案，能从 `wg show` 判断“没握手”与“有握手但无外网”是两类问题。
2. 能通过 `route print -4` 解释为什么普通 IPv4 访问会进入隧道。
3. 能用 UFW Forward 规则、IP Forwarding、NAT 计数器解释一个回程流量问题。
4. 能证明自己记录的 ISP 代理出口不是凭猜测得来的。
5. 能针对一个错误出具包含现象、推论、证据、修复和验证的故障报告。

**自测**：
- 问：`latest handshake` 很新是否代表 DNS 一定正常？答：否；仅证明 WireGuard Peer 近期完成握手。
- 问：POSTROUTING 计数为 0 意味着 VPN 一定失败？答：不一定，也可能尚未产生符合条件的转发流量、接口名写错或请求走了别的路径。
- 问：成功 SSH 登录 VPS 是否意味着 UDP 51820 已放行？答：否，SSH TCP 与 WireGuard UDP 是不同服务及端口。

**官方参考（核验日：2026-10-30）**：
- Ubuntu WireGuard Troubleshooting: https://ubuntu.com/server/docs/wireguard-vpn-troubleshooting/
- Ubuntu Firewall: https://ubuntu.com/server/docs/how-to/security/firewalls/
- Microsoft Test-NetConnection: https://learn.microsoft.com/en-us/powershell/module/nettcpip/test-netconnection?view=windowsserver2025-ps

---

<a id="part-9"></a>

# 第九篇｜把实验整理为 GitHub 工程项目与简历成果

> 技术项目的说服力来自**可复现性、测试证据、安全边界与诚实的完成记录**，而不是一堆能跑的一键脚本。GitHub 只发布脱敏的技术文档、配置模板、只读检查脚本，不发布生产密钥或真实店铺/客户数据。

## 1. 建议仓库结构

```text
cross-border-network-lab/
├── README.md                   项目总览、学习路线、架构与警告
├── docs/                       九篇完整教程
├── configs/                    .example.conf 脱敏样例
├── scripts/
│   ├── network-check.ps1        Windows 只读网络检查
│   └── vps-readonly-check.sh    Ubuntu 只读诊断
├── tests/acceptance-checklist.md
├── troubleshooting/incident-template.md
├── diagrams/topology.md
├── .gitignore
└── LICENSE（如果需要公开授权使用，再自行选合适许可证）
```

## 2. Git 最小工作流（Windows PowerShell）

下载本教材仓库模板，在 VS Code 打开根目录；确认安装 Git：

```powershell
git --version
cd PATH_TO_YOUR_EXTRACTED_REPOSITORY
git init
git status
```

先查 `.gitignore`，逐个审阅目录内容后再提交。建议**显式**添加文件，不使用未经检查的 `git add .`：

```powershell
git add README.md .gitignore
git add docs/01-network-fundamentals.md
git diff --cached --stat
git diff --cached
git commit -m "docs: add safe network fundamentals and project overview"
```

后续逐章增加并审查。第一次推送到 GitHub 前确认仓库默认是**私有**还是**公开**，仔细查看 staged 文件是否包含真实网络地址、私钥或商家认证信息。公开仓库应仅包含示例 IP（例如 `203.0.113.5`）、示例域名、脱敏日志。

## 3. `.gitignore` 不是事后擦除历史

典型的安全规则在根目录 `.gitignore`（已经随模板提供）。**GitHub 明确指出**：`.gitignore` 只能避免尚未被跟踪的文件被意外加入；已经提交的密钥即使删除文件，仍可能存在于 Git 历史和其他克隆中。一旦泄露，立即吊销/轮换密钥，后续再按照 GitHub 官方方法处理仓库历史。

**推荐措施**：
- 配置模板仅放占位符，真实 `/etc/wireguard/wg0.conf` 留在 VPS 且权限为 600。
- 在 PowerShell 使用交互输入代理口令，不把密码写进 `.ps1` 文件。
- 公开日志前移除实际 VPS/IP、代理入口、认证字段和业务数据。
- 使用 `git diff --cached` 审查；启用 GitHub secret scanning / push protection（如对应账户/仓库支持）。

## 4. 可复现性与测试报告

一个好的 README 要回答：“它解决什么问题？适用哪些系统？依赖什么？部署前注意什么风险？怎么验收？没成功怎么办？”

记录实验状态时使用这些列：

| 功能 | 状态 | 证据 | 风险/下一步 |
|---|---|---|---|
| Windows→VPS WireGuard | 未测试/已测试/通过/失败 | 脱敏握手、IP 验证 | IPv6/DNS 待审计 |
| VPS NAT | 同上 | 转发规则、计数器 | 云安全组已核对 |
| ISP 代理路径 B | 同上 | 匿名化 IP 对照 | 代理协议已确认 |
| ISP 代理路径 C | 同上 | 入口连接路径、最终出口 | 非所有应用通用 |
| 美国/日本出口 | 各地区单独填 | 证据 | 不虚构不存在的出口 |
| Kill Switch/DNS/IPv6 | 同上 | 断线测试 | 不宣称零风险 |

## 5. 工程总结应该突出什么

**设计**：区分 L3 VPN 和 L7/L5 应用代理、制定出口需求和测试条件。**实施**：Linux/SSH 管理、WireGuard Peer 配置、IPv4 Forwarding、UFW/NAT、安全回滚。**验证**：客户端路由、服务端握手、curl 出口对照、应用级代理行为。**运维**：日志检查、密钥管理、故障实验和可审计文档。

不要把“用 AI 帮我写了部署教程”包装成“我独立实现了高可用全球网络”。如果只是跑通一个 WireGuard VPN，应如实写出这个范围；若已经实际完成更多功能，再把对应的验收证据补上。

### 中文简历描述（完成验收后选用）

> 设计并搭建基于 Ubuntu VPS 与 Windows 的 WireGuard 网络实验环境，配置 IPv4 路由、IP 转发、源 NAT 和主机防火墙；通过路由表、握手状态及外网出口对照验证链路，并编写故障排查与安全部署文档。另对 HTTP/SOCKS5 代理链路开展可复现的应用级测试（仅在已完成该部分时使用）。

### English résumé description (use only for completed work)

> Built and documented a Windows-to-Ubuntu WireGuard networking lab, configuring IPv4 routing, packet forwarding, source NAT, and host firewall rules. Validated connectivity using route inspection, tunnel handshakes, and external egress-IP checks, and developed reproducible troubleshooting and security checklists. Evaluated application-level HTTP/SOCKS proxy paths where tested.

## 6. 最终知识自测（含答案）

1. IP 转发与 NAT 各有什么作用？**答案**：前者决定允许跨接口转发数据包，后者改变地址以支持公网回程；二者不能互相代替。
2. 为什么不能从 WireGuard 握手证明 DNS/IPv6/代理无泄漏？**答案**：握手仅验证 Peer 加密通信，DNS/IPv6 与应用代理路径另由各自的路由、解析器和客户端行为控制。
3. `AllowedIPs=0.0.0.0/0` 的精确含义？**答案**：在发送方的 WireGuard 配置语境下覆盖全部 IPv4 目标；不覆盖 IPv6，也不代表所有应用自动使用 ISP 代理。
4. 哪一种密钥可以交换给对方 Peer？**答案**：公钥；私钥不可公开。
5. 为什么 C 路径的网站看到 ISP 代理 IP？**答案**：对于明确配置了代理的请求，ISP 代理是面向网站发出请求的最后出口。
6. 为什么 `git rm` 或从 README 删除口令仍不够？**答案**：Git 历史和他人克隆可能保留原内容，必须尽快轮换受影响凭据。
7. 如何检验日美双出口已经实现？**答案**：每个出口都在相同时间窗内有独立的可复现外网连接、IP/地理信息核验与路径记录。
8. 远程修改防火墙前做什么？**答案**：确认云控制台/控制台救援可用、配置快照、原端口规则、保留第二 SSH 会话与回滚方案。

## 7. 下一阶段课程建议

当你确实完成单 VPS/VPN 实验后，再选学：Linux `ip rule` 与多路由表、nftables、IPv6 路由、网络命名空间、Docker 网络隔离、Ansible、自动化 CI、Prometheus/Grafana。它们是进阶方向，不是第一天搭建 VPN 的门槛。

**官方参考（核验日：2026-10-30）**：
- GitHub Ignoring Files: https://docs.github.com/en/get-started/git-basics/ignoring-files
- GitHub Removing Sensitive Data: https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/removing-sensitive-data-from-a-repository
- GitHub Docs: https://docs.github.com/

---

<a id="part-10"></a>

# 官方资料与继续学习路线

> 资料检索与版本核验日期：**2026-10-30**。链接指向官方机构或项目维护者页面。没有执行真实 VPS 部署，也没有验证你已购买的具体 ISP 代理的可用性；网站版本和政策可能变动。

| 来源 | 优先学习的知识点 | 对应篇章 |
|---|---|---|
| [Cloudflare Learning: What is DNS](https://www.cloudflare.com/learning/dns/what-is-dns/) | DNS 的基本过程与隐私限制 | 1、7 |
| [Microsoft: Windows VPN routing decisions](https://learn.microsoft.com/en-us/windows/security/operating-system-security/network-security/vpn/vpn-routing) | Split tunnel 与 Force tunnel、路由 | 1、6、7 |
| [Microsoft: Test-NetConnection](https://learn.microsoft.com/en-us/powershell/module/nettcpip/test-netconnection?view=windowsserver2025-ps) | Windows TCP/路由诊断 | 1、8 |
| [Ubuntu: Release cycle](https://ubuntu.com/about/release-cycle) | 核对 24.04/26.04 LTS 的维护情况 | 2、3 |
| [Ubuntu: OpenSSH server](https://ubuntu.com/server/docs/openssh-server/) | SSH、公私钥和服务管理 | 3 |
| [Microsoft: OpenSSH key management](https://learn.microsoft.com/en-us/windows-server/administration/openssh/openssh_keymanagement) | Windows SSH 密钥生成 | 3 |
| [WireGuard: Installation](https://www.wireguard.com/install/) | Windows 和 Linux 官方安装 | 4 |
| [WireGuard: Quick Start](https://www.wireguard.com/quickstart/) | Peer、公私钥、Keepalive | 4、7 |
| [Ubuntu: Introduction to WireGuard](https://ubuntu.com/server/docs/wireguard-vpn-introduction/) | AllowedIPs、Peer、Endpoint | 4 |
| [Ubuntu: WireGuard as Default Gateway](https://ubuntu.com/server/docs/wireguard-vpn-defaultgw/) | IP Forwarding、SNAT、DNS | 4、7 |
| [Ubuntu: Firewall & UFW](https://ubuntu.com/server/docs/how-to/security/firewalls/) | UFW 转发和 `before.rules` NAT | 3、4、8 |
| [Ubuntu: Troubleshooting WireGuard](https://ubuntu.com/server/docs/wireguard-vpn-troubleshooting/) | 握手、路由和故障定位 | 4、8 |
| [curl: Proxy manual](https://curl.se/docs/manpage.html) | `-x`、`-U`、SOCKS 和 HTTP | 2、5、6 |
| [everything curl: SOCKS proxy](https://everything.curl.dev/usingcurl/proxies/socks.html) | `socks5` 与 `socks5h` 的 DNS 差异 | 1、5 |
| [everything curl: HTTP Proxy](https://everything.curl.dev/usingcurl/proxies/http.html) | HTTP CONNECT 与代理路径 | 5 |
| [WireGuard Windows: networking quirks](https://git.zx2c4.com/wireguard-windows/about/docs/netquirk.md) | WireGuard Windows Kill Switch 的前提与规则 | 7 |
| [Ubuntu: Automatic updates](https://ubuntu.com/server/docs/how-to/software/automatic-updates/) | 安全更新与维护 | 3、7 |
| [GitHub: Ignoring Files](https://docs.github.com/en/get-started/git-basics/ignoring-files) | `.gitignore` 与敏感文件防误提交 | 9 |
| [GitHub: Removing Sensitive Data](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/removing-sensitive-data-from-a-repository) | 泄漏后的密钥轮换与 Git 历史处理 | 9 |

## 阅读顺序

第一周：Cloudflare DNS → Microsoft 路由 → Ubuntu SSH → Windows 网络命令。

第二周：WireGuard Introduction → Quick Start → Ubuntu Default Gateway → UFW Firewall。

第三周：curl HTTP/SOCKS Proxy → Windows WireGuard netquirk → Ubuntu Troubleshooting。

第四周：GitHub 安全 → 完成实验自测 → 审核仓库再公开。

> 以上周期仅是可选学习节奏，不是任务完成的承诺或性能保证。可按个人学习速度调整。

---

## 附录：配套可执行与验收模板

配套工程包包含 `configs/wg0.server.example.conf`、`configs/wg0.windows.example.conf`、`scripts/network-check.ps1`、`scripts/vps-readonly-check.sh`、`tests/acceptance-checklist.md`、`troubleshooting/incident-template.md`、`diagrams/topology.md` 和 `.gitignore`。这些文件需随项目包一起取用；本单文件教材已包含完整配置步骤与知识自测。
