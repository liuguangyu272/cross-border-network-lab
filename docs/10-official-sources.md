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
