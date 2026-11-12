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
