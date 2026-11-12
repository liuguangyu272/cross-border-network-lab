<#
.SYNOPSIS
  Read-only Windows network diagnostic for the Cross-Border Network Lab.
.DESCRIPTION
  Does not change DNS, routes, firewalls, VPN, or proxy settings.
  Optional egress-IP query sends an HTTPS request to api.ipify.org. Do not publish raw results.
.EXAMPLE
  .\scripts\network-check.ps1
  .\scripts\network-check.ps1 -CheckPublicIPv4
#>
param([switch] $CheckPublicIPv4)

$ErrorActionPreference = 'Continue'
Write-Host '=== Network lab: read-only baseline ==='
Write-Host ('Time: ' + (Get-Date -Format o))
Write-Host ('Windows: ' + [System.Environment]::OSVersion.VersionString)

Write-Host "`n=== IPv4 routes ==="
Get-NetRoute -AddressFamily IPv4 -ErrorAction SilentlyContinue |
  Sort-Object DestinationPrefix, RouteMetric |
  Select-Object -First 30 DestinationPrefix, InterfaceAlias, NextHop, RouteMetric |
  Format-Table -AutoSize

Write-Host "`n=== DNS settings (may expose private network data; do not share raw output) ==="
Get-DnsClientServerAddress -ErrorAction SilentlyContinue |
  Select-Object InterfaceAlias, AddressFamily, ServerAddresses |
  Format-Table -AutoSize

Write-Host "`n=== IPv4 / IPv6 enabled interfaces ==="
Get-NetIPInterface -ErrorAction SilentlyContinue |
  Select-Object InterfaceAlias, AddressFamily, ConnectionState, InterfaceMetric |
  Format-Table -AutoSize

Write-Host "`n=== DNS test for example.com ==="
try { Resolve-DnsName example.com -ErrorAction Stop | Select-Object -First 4 Name, Type, IPAddress | Format-Table -AutoSize }
catch { Write-Warning 'DNS query failed. Check network route and resolver.' }

if ($CheckPublicIPv4) {
  Write-Host "`n=== Public IPv4 (HTTPS request to api.ipify.org; may reveal your IP to this service) ==="
  if (Get-Command curl.exe -ErrorAction SilentlyContinue) {
    & curl.exe -4 --noproxy '*' --connect-timeout 5 --max-time 12 https://api.ipify.org
    Write-Host "`n"
  } else { Write-Warning 'curl.exe not found.' }
}
Write-Host "`nDone. Redact IPs, DNS servers, routes and interface identifiers before sharing."
