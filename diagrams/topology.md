# 文字网络拓扑（可贴到 GitHub 的 Markdown）

```text
【路径 A：基础 WireGuard VPN】
 Windows: 10.66.66.2
       │ WireGuard over UDP/51820 (encrypted)
       ▼
 VPS: wg0 10.66.66.1 ── IP Forwarding ── SNAT on WAN_IF ── HTTPS Website

【路径 B：应用显式 ISP 代理】
 Windows supporting app ── HTTP CONNECT or SOCKS5 ── ISP proxy ── Website

【路径 C：同一应用先经过 WireGuard 再访问代理】
 Windows supporting app ── WG tunnel ── VPS WAN ── ISP proxy ── Website
       │                          │              │
       └─ IPv4 routed into wg0    └─ acts as IP gateway
                                      Website usually sees proxy egress IP
```

## 两层 IP 地址示例

- Windows 私网 WG：`10.66.66.2/32`
- VPS VPN 接口：`10.66.66.1/24`
- VPS 公网 IP：由已购 VPS 实际情况决定
- ISP Proxy 入口和出口：由商家实际服务和访问结果决定，二者可以不一致
- 文档示例外网 IP：`203.0.113.5`（不可实际访问的示例地址）

## 不能从图中直接推出的内容

- 并非所有 Windows 应用支持代理，也不是所有 UDP/IPv6 流量走 ISP 代理。
- 代理使用地区不等于经营身份或业务合规地区。
- DNS 查询和浏览器 DoH 可能走另外的路径，需要实际审计。
