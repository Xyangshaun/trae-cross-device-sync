# Trae 跨设备迁移 · 源端一键打包（Windows PowerShell）
# 用法: .\pack.ps1 -Project "C:\Users\<用户名>\my-app" [-Out DIR] [-Solo] [-WithDeps] [-SecretsFrom DIR]
# 产出: project-full.tar.gz / trae-cn-final.tar.gz / trae-appdata-chat.tar.gz
#       [trae-appdata-solo-chat.tar.gz] / [secrets.tar.gz] / SHA256SUMS.txt
param(
  [Parameter(Mandatory = $true)][string]$Project,
  [string]$Out = "",
  [switch]$Solo,
  [switch]$WithDeps,
  [string]$SecretsFrom = ""
)
$ErrorActionPreference = "Stop"
if (-not (Test-Path $Project)) { Write-Host "❌ 项目路径不存在: $Project"; exit 2 }
$Project = (Resolve-Path $Project).Path
$ProjName = Split-Path $Project -Leaf
if (-not $SecretsFrom) { $SecretsFrom = $Project }
$Stamp = Get-Date -Format "yyyyMMdd-HHmmss"
if (-not $Out) { $Out = Join-Path $env:USERPROFILE "Desktop\trae-migration-$Stamp" }
New-Item -ItemType Directory -Force -Path $Out | Out-Null

Write-Host "==> [0/5] 环境检查"
$trae = Get-Process -Name "*Trae*" -ErrorAction SilentlyContinue
if ($trae) {
  Write-Host "⚠️  检测到 Trae 正在运行。为保存聊天库一致，请完全退出 Trae 后重跑；"
  Read-Host "    或确认已退出后按回车继续"
}

Write-Host "==> [1/5] 打包项目（$ProjName）"
$ex = @("--exclude=node_modules", "--exclude=.venv", "--exclude=venv", "--exclude=__pycache__", "--exclude=dist")
if ($WithDeps) { $ex = @() }
tar -czf "$Out\project-full.tar.gz" -C (Split-Path $Project -Parent) @ex $ProjName

Write-Host "==> [2/5] 打包全局配置（~\.trae-cn）"
$traeCn = Join-Path $env:USERPROFILE ".trae-cn"
if (Test-Path $traeCn) {
  $tmp = Join-Path $Out ".trae-cn"
  Copy-Item -Recurse -Force $traeCn $tmp
  Get-ChildItem -Recurse -File $tmp -Filter *.log -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue
  Get-ChildItem -Recurse -Directory $tmp -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -like "Cache*" -or $_.Name -eq "logs" } |
    Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
  tar -czf "$Out\trae-cn-final.tar.gz" -C $Out ".trae-cn"
  Remove-Item -Recurse -Force $tmp
} else { Write-Host "    跳过：未找到 ~\.trae-cn" }

Write-Host "==> [3/5] 打包应用数据（聊天库）"
$appBase = $env:APPDATA
if (Test-Path (Join-Path $appBase "Trae CN")) {
  tar -czf "$Out\trae-appdata-chat.tar.gz" -C $appBase "Trae CN"
}
if ($Solo -and (Test-Path (Join-Path $appBase "TRAE SOLO CN"))) {
  tar -czf "$Out\trae-appdata-solo-chat.tar.gz" -C $appBase "TRAE SOLO CN"
}

Write-Host "==> [4/5] 打包密钥"
$items = @()
if (Test-Path (Join-Path $SecretsFrom ".env")) { $items += ".env" }
if (Test-Path (Join-Path $SecretsFrom "deploy\secrets")) { $items += "deploy/secrets" }
if ($items.Count -gt 0) {
  tar -czf "$Out\secrets.tar.gz" -C $SecretsFrom @items
} else { Write-Host "    跳过：未发现 .env 或 deploy\secrets" }

Write-Host "==> [5/5] 生成校验与汇总"
Get-ChildItem $Out -Filter *.tar.gz | ForEach-Object {
  $h = (Get-FileHash $_.FullName -Algorithm SHA256).Hash.ToLower()
  "$h  $($_.Name)"
} | Set-Content -Encoding ascii (Join-Path $Out "SHA256SUMS.txt")

Write-Host ""
Write-Host "✅ 打包完成：$Out"
Get-ChildItem $Out | ForEach-Object { Write-Host ("    {0,-38} {1}" -f $_.Name, $_.Length) }
Write-Host ""
Write-Host "📦 传输方式（任选其一）：U盘 / 网盘 / 局域网共享"
Write-Host "   传输五件套：project-full.tar.gz · trae-cn-final.tar.gz ·"
Write-Host "   trae-appdata-chat.tar.gz · secrets.tar.gz（如有）· SHA256SUMS.txt"
Write-Host "⚠️  迁移包含密钥与聊天记录，走可信通道，传输完在旧设备保留 1-2 周再删"
Write-Host ""
Write-Host "→ 新电脑上装好 Trae 后，把迁移包放到任意目录，说一句："
Write-Host '   「迁移包在 <路径>，帮我恢复」'
