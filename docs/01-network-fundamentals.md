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
