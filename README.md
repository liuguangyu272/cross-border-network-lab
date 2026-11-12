# 从零到初级网络工程实践：Windows + VPS + 静态 ISP 代理

**学习型工程项目 / Cross-border Network Lab**｜中文版｜核验日期：2026-10-30

> 本仓库是合法、授权的网络工程实验教材，不是匿名保证、跨境电商平台风控规避方案，也不承诺任何业务平台的账号安全。生产环境修改前需备份、审批和维护窗口。示例参数、网段和密钥占位符不可直接当作真实业务配置。

## 适合谁

有 Windows 电脑、已购买 VPS 和静态 ISP 代理，希望理解网络基础、搭建 WireGuard、验证美国或日本的合法网络出口，并通过 GitHub 文档化实践的零基础学习者。**不要求提前理解 DNS、IPv6、Kill Switch、NAT、Linux 等专业术语。**

## 学习路径（先学理论，再动手）

1. [第一篇：网络基础](docs/01-network-fundamentals.md)——IP、路由、DNS、TCP/UDP、NAT、VPN 与代理。
2. [第二篇：审计现有资源](docs/02-existing-resources.md)——VPS 与 ISP 代理到底有什么差别。
3. [第三篇：Linux 和 SSH](docs/03-linux-ssh-security.md)——安全访问 VPS，备份和防火墙。
4. [第四篇：部署 WireGuard](docs/04-wireguard-deploy.md)——手动配置 Windows → VPS → Internet。
5. [第五篇：ISP 代理链](docs/05-isp-proxy-chains.md)——明确验证 A/B/C 三条路径。
6. [第六篇：美国/日本双出口](docs/06-us-jp-routing.md)——多出口应用代理与路由。
7. [第七篇：可靠性与安全](docs/07-reliability-security.md)——DNS、IPv6、Kill Switch、监控。
8. [第八篇：故障排查](docs/08-troubleshooting-lab.md)——10 个场景的系统化诊断。
9. [第九篇：GitHub 工程](docs/09-github-project.md)——文档、测试、安全和简历表达。

也可阅读仓库外提供的单文件合并版 `network-engineering-textbook.md`。

## 最终架构

```text
A: Windows ─ WireGuard ─ VPS ─ Internet       网站通常看到 VPS 出口 IP
B: Windows ─ ISP Proxy ─ Internet           网站通常看到代理出口 IP
C: Windows ─ WireGuard ─ VPS ─ ISP Proxy ─ Internet
   （C 仅对明确使用代理的应用流量成立，不能据此推断全系统所有协议自动代理）
```

**最重要的两个技术边界**：WireGuard VPN 并不会自动将流量交给 ISP 代理；`AllowedIPs=0.0.0.0/0` 只覆盖 IPv4。DNS、IPv6 和掉线的安全行为必须单独测试。

## 迅速找到需要的内容

- **零基础**：先读第一篇，运行 `ipconfig /all`、`route print -4`、`Resolve-DnsName`。
- **已有 VPS**：第二篇审计 OS、SSH 端口和出站接口；不要重装不必要的服务器。
- **第一次部署**：第四篇是唯一基础部署主线，包含前置检查、备份、每条命令解释和故障恢复。
- **ISP 代理**：第五篇先用 curl 显式代理测通，**不要**一开始就尝试复杂透明代理。
- **GitHub**：只上传 `*.example.conf` 和只读脚本；真实秘钥留在本机或安全的私有存储。

## 实验环境/前提

| 项目 | 基线 | 说明 |
|---|---|---|
| Windows | 10/11 + PowerShell + WireGuard 官方客户端 | 有管理员权限安装软件 |
| VPS | 优先参考 Ubuntu Server 24.04 LTS | 2026 已有 26.04 LTS，若版本不同需逐条核对 |
| VPN 子网 | `10.66.66.0/24` | **必须检查地址冲突** |
| WireGuard UDP | 51820 | 需在 Linux 和云安全组同时开放 |
| SSH | 由已有实例确认 | 不要假定一定是 TCP/22 |
| ISP 代理 | HTTP/HTTPS/SOCKS5，取决于购买的真实套餐 | 入口协议/认证/地区必须实测 |
| IPv6 | 首次实验仅建立 IPv4 基线 | 未经过验证的环境不得宣称无泄漏 |

## 工具/模板

- [WireGuard 服务端模板](configs/wg0.server.example.conf)
- [WireGuard Windows 模板](configs/wg0.windows.example.conf)
- [Windows 只读网络自检](scripts/network-check.ps1)
- [Ubuntu 只读网络自检](scripts/vps-readonly-check.sh)
- [验收清单](tests/acceptance-checklist.md)
- [故障记录模板](troubleshooting/incident-template.md)
- [数据流架构图](diagrams/topology.md)
- [官方参考资料](docs/10-official-sources.md)

## 安全和合规

- 不保存或共享 WireGuard 私钥、真实代理认证数据、店铺会话、支付数据或未脱敏日志。
- 修改远程防火墙或 SSH 前，先核实 VPS 救援控制台、第二个 SSH 会话、回滚方法与快照。
- 不承诺固定 IP、ISP IP 可避免风控/账号关联；平台条款、商户身份、税务/KYC 和当地法律法规仍应独立遵守。
- 教材中的命令为人工审阅的示例；未经连接你的实际 VPS，**没有完成你的真实部署，也没有进行连接性能测试**。

## 许可证与贡献

本教程不附加未经选择的开放许可；若准备对外授权使用，请先选择适当 LICENSE。仅在确认无秘密信息的前提下分享仓库。任何贡献应附上所依据的官方文档及验证环境。
