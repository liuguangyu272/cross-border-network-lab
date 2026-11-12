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
