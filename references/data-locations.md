# 数据位置对照与打包命令

## §1 `%APPDATA%` 与 `~` 说明

- `%APPDATA%` = `C:\Users\<用户名>\AppData\Roaming`（PowerShell 中为 `$env:APPDATA`）
- `~` = `/Users/<用户名>`（macOS）
- Windows 上 TRAE SOLO 与 Trae CN 数据分库存放：`%APPDATA%\TRAE SOLO CN\` 与 `%APPDATA%\Trae CN\`；聊天数据在各自的 `ModularData\ai-agent\database.db`（含 `-wal`/`-shm`）

## §2 目标端数据目录对照表

| 数据 | Windows | macOS |
|------|---------|-------|
| AI 记忆 / skills / plugins / mcps | `%USERPROFILE%\.trae-cn\` | `~/.trae-cn/` |
| 应用数据（聊天库/IndexedDB/机器标识） | `%APPDATA%\Trae CN\`、`%APPDATA%\TRAE SOLO CN\` | `~/Library/Application Support/Trae CN/` |
| 迁移作业文件 | 应用数据根目录 `migration-job.json` | 同左 |

## §2.2 项目记忆路径编码规则

记忆按项目绝对路径隔离：`<记忆根>/projects/<路径编码>--p2-<哈希>/`

- 编码规则：路径分隔符替换为 `-`，开头加 `-`
  - Windows `C:\Users\张三\my-app` → `-c-Users-张三-my-app--p2-xxxx`
  - macOS `/Users/张三/my-app` → `-Users-张三-my-app--p2-xxxx`
- `--p2-<哈希>` 由 Trae 内部生成，**无法凭空构造**——必须先在目标端用 Trae 打开项目并让 AI 响应一次，等它自己生成文件夹
- 文件夹内结构：`project_memory.md`（长期记忆）+ `2026MMDD/topics.md`（话题摘要）+ `2026MMDD/session_memory_<id>.jsonl`（消息级）

## §3 源端打包命令

### Windows（PowerShell，打包前关闭 Trae）

```powershell
# 1. 项目（含 .git；node_modules 可选）
tar -czf project-full.tar -C C:\Users\<用户名> <项目目录名>

# 2. 全局配置（复制后剔除 Windows 专用 skills/mcps/tools 与登录态文件再打包）
Copy-Item -Recurse ~\.trae-cn ~\.trae-cn.pack
tar -czf trae-cn-final.tar.gz -C ~ .trae-cn.pack
Remove-Item -Recurse ~\.trae-cn.pack

# 3. 应用数据（聊天库等；只用过一个客户端就只打对应目录）
tar -czf trae-appdata-chat.tar.gz -C "$env:APPDATA" "Trae CN" "TRAE SOLO CN"

# 4. 密钥
tar -czf secrets.tar.gz -C <项目根> .env deploy/secrets

# 5. 校验清单
Get-FileHash *.tar, *.tar.gz | Format-Table -AutoSize | Out-File SHA256SUMS.txt
```

### macOS（bash）

```bash
# 1. 项目
tar -czf project-full.tar -C ~ <项目目录名>

# 2. 全局配置
cp -R ~/.trae-cn ~/.trae-cn.pack
# 剔除平台专用项后：
tar -czf trae-cn-final.tar.gz -C ~ .trae-cn.pack && rm -rf ~/.trae-cn.pack

# 3. 应用数据
tar -czf trae-appdata-chat.tar.gz -C ~/Library/"Application Support" "Trae CN"

# 4. 密钥 + 5. 校验
tar -czf secrets.tar.gz -C <项目根> .env deploy/secrets
shasum -a 256 *.tar *.tar.gz > SHA256SUMS.txt
```

### 传输清单（五件套）

`project-full.tar`（项目）· `trae-cn-final.tar.gz`（配置）· `trae-appdata-chat.tar.gz`（聊天库）· `secrets.tar.gz`（密钥）· `SHA256SUMS.txt`（校验）。另建议：人类可读历史日志 Markdown（认知层备份）。

## §4 目标端放置映射

| 包 | macOS 去处 | Windows 去处 |
|----|-----------|-------------|
| project-full.tar | `tar -xf` 到 `~/项目目录` | 解压到 `%USERPROFILE%\项目目录` |
| trae-cn-final.tar.gz | 内容并入 `~/.trae-cn/`（先备份） | 并入 `%USERPROFILE%\.trae-cn\`（先备份） |
| trae-appdata-chat.tar.gz | 先解压到任意临时目录（供 chat-migration 流程读取），**不直接放进应用数据目录** | 同左 |
| secrets.tar.gz | 解压回项目内对应位置，私钥 `chmod 600` | 解压回项目内 |
