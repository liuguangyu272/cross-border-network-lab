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
