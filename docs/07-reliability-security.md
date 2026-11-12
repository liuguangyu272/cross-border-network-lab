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
