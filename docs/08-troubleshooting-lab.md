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
