# Trae 跨设备迁移 · 目标端一键恢复（Windows PowerShell）
# 用法: .\restore.ps1 -Dir <迁移包目录> [-ProjectDest DIR] [-SkipProject]
# 退出码: 0 成功 / 2 参数错 / 3 项目已存在(需用户决策) / 4 校验失败
param(
  [Parameter(Mandatory = $true)][string]$Dir,
  [string]$ProjectDest = "",
  [switch]$SkipProject
)
$ErrorActionPreference = "Stop"
if (-not (Test-Path $Dir)) { Write-Host "❌ 迁移包目录不存在: $Dir"; exit 2 }
$Pkg = (Resolve-Path $Dir).Path
if (-not $ProjectDest) { $ProjectDest = $env:USERPROFILE }
$ProjectDest = (Resolve-Path $ProjectDest).Path

Write-Host "==> [1/7] 校验传输完整性（SHA256）"
$sums = Join-Path $Pkg "SHA256SUMS.txt"
if (Test-Path $sums) {
  $ok = $true
  Get-Content $sums | ForEach-Object {
    $parts = $_ -split "\s+", 2
    if ($parts.Count -eq 2) {
      $f = Join-Path $Pkg $parts[1].Trim()
      if (Test-Path $f) {
        $h = (Get-FileHash $f -Algorithm SHA256).Hash.ToLower()
        if ($h -ne $parts[0].ToLower()) { Write-Host "❌ 校验失败: $($parts[1])"; $ok = $false }
      } else { Write-Host "❌ 缺失文件: $($parts[1])"; $ok = $false }
    }
  }
  if (-not $ok) { exit 4 } else { Write-Host "    全部通过" }
} else { Write-Host "    跳过：未找到 SHA256SUMS.txt" }

$projPath = ""
if (-not $SkipProject -and (Test-Path (Join-Path $Pkg "project-full.tar.gz"))) {
  Write-Host "==> [2/7] 恢复项目"
  $first = (tar -tzf (Join-Path $Pkg "project-full.tar.gz") | Select-Object -First 1)
  $projName = ($first -split "/")[0].TrimEnd("\", "/")
  if (Test-Path (Join-Path $ProjectDest $projName)) {
    Write-Host "❌ 目标已存在: $(Join-Path $ProjectDest $projName)"
    Write-Host "    处理方式交由用户确认：复用(-SkipProject) / 备份后替换 / 改 -ProjectDest 换位置"
    exit 3
  }
  tar -xzf (Join-Path $Pkg "project-full.tar.gz") -C $ProjectDest
  $projPath = Join-Path $ProjectDest $projName
  Write-Host "    已恢复 → $projPath"
} elseif ($SkipProject) {
  Write-Host "==> [2/7] 按要求跳过项目恢复"
}

Write-Host "==> [3/7] 恢复全局配置（并入 ~\.trae-cn，先备份）"
$cnTar = Join-Path $Pkg "trae-cn-final.tar.gz"
if (Test-Path $cnTar) {
  $traeCn = Join-Path $env:USERPROFILE ".trae-cn"
  if (Test-Path $traeCn) {
    $bak = "$traeCn.bak-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
    Copy-Item -Recurse -Force $traeCn $bak
    Write-Host "    已备份 → $bak"
  }
  $tmpd = Join-Path $env:TEMP ("trae-restore-" + [guid]::NewGuid().ToString("N"))
  New-Item -ItemType Directory -Force -Path $tmpd | Out-Null
  tar -xzf $cnTar -C $tmpd
  New-Item -ItemType Directory -Force -Path $traeCn | Out-Null
  Copy-Item -Recurse -Force (Join-Path $tmpd ".trae-cn\*") $traeCn
  Remove-Item -Recurse -Force $tmpd
  Write-Host "    已并入 ~\.trae-cn"
}

if ($projPath -and (Test-Path $projPath)) {
  Write-Host "==> [4/7] 恢复密钥"
  $secTar = Join-Path $Pkg "secrets.tar.gz"
  if (Test-Path $secTar) { tar -xzf $secTar -C $projPath }

  Write-Host "==> [5/7] 清理 git 跨平台遗留"
  if (Test-Path (Join-Path $projPath ".git")) {
    git -C $projPath config --local --unset-all http.proxy 2>$null
    git -C $projPath config --local --unset-all https.proxy 2>$null
    git -C $projPath config --local core.autocrlf false
    git -C $projPath log --oneline -1
  }
}

Write-Host "==> [6/7] 解压聊天库到 work\（不直接进应用数据目录）"
$work = Join-Path $Pkg "work"
New-Item -ItemType Directory -Force -Path $work | Out-Null
foreach ($n in @("trae-appdata-chat.tar.gz", "trae-appdata-solo-chat.tar.gz")) {
  $t = Join-Path $Pkg $n
  if (Test-Path $t) { tar -xzf $t -C $work }
}

Write-Host "==> [7/7] 生成 migration-job.json（待用户确认后执行）"
function Gen-Job($src, $tgt, $out) {
  $mid = [guid]::NewGuid().ToString()
  @{
    migrationId = $mid; source = $src; target = $tgt; status = "pending"; removeApp = $false
  } | ConvertTo-Json | Set-Content -Encoding UTF8 $out
  Write-Host "    已生成: $out"
}
$targetAppData = Join-Path $env:APPDATA "Trae CN"
$srcTrae = Join-Path $work "Trae CN"
if ((Test-Path $srcTrae) -and (Test-Path $targetAppData)) {
  Gen-Job $srcTrae $targetAppData (Join-Path $work "migration-job.json")
}
$targetSolo = Join-Path $env:APPDATA "TRAE SOLO CN"
$srcSolo = Join-Path $work "TRAE SOLO CN"
if ((Test-Path $srcSolo) -and (Test-Path $targetSolo)) {
  Gen-Job $srcSolo $targetSolo (Join-Path $work "migration-job-solo.json")
}

Write-Host ""
Write-Host "✅ 自动恢复完成。剩余步骤（AI 引导执行）："
if ($projPath) { Write-Host "    1. 项目 $projPath：安装依赖并启动验证（Node 20+，与源端一致）" }
Write-Host "    2. 记忆挂接：在 Trae 中打开项目让 AI 响应一次 → 合并项目记忆（见 references/data-locations.md §2.2）"
if (Test-Path (Join-Path $work "migration-job.json")) {
  Write-Host "    3. 聊天迁移：向用户确认后，把 migration-job.json 复制到 target 根目录并执行"
  Write-Host '       start "" "trae-cn://migration?migrationId=<json 内的 migrationId>"（详情见 references/chat-migration.md）'
}
Write-Host "    4. 按 references/chat-migration.md §验收清单逐项打勾"
