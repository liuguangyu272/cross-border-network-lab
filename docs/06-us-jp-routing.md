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
