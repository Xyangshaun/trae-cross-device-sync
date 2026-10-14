---
name: trae-cross-device-sync
description: 把 Trae 上下文完整迁移到另一台设备——项目代码、AI 项目记忆、全局配置、逐字聊天库与密钥。两句话完成：一句打包、手动传输、一句恢复。覆盖 Win 转 Mac、Win 转 Win、Mac 转 Mac。当用户提到换电脑、换机、迁移 Trae 数据、同步聊天记录、跨设备同步上下文时使用。不适用于仅用 git 同步代码或常规项目部署的场景。
slug: xyangshaun-trae-cross-device-sync
displayName: Trae 跨设备上下文完整同步
version: 1.1.0
summary: 基于 Trae 客户端内置官方迁移机制（migration-job.json + deeplink）的逆向与 Win→Mac 实测。一句话让 AI 自动打包五类数据生成迁移包，手动传到新电脑后，再一句话 AI 自动恢复并验收。v1.1 起内置自动化脚本，全程只需手动传输文件。
license: MIT
---

# Trae 跨设备上下文同步

带领用户完成 Trae 全部上下文（五类数据）的跨设备迁移。**默认两句话模式**：脚本能做的 AI 直接做，用户唯一手动环节是传输迁移包；只有覆盖目标已有数据、写入聊天库前才停下来确认。

## 铁律

1. **先备份后动手**：目标端将被写入的既有目录，先做带日期后缀的备份（脚本已内置）
2. **不盲目覆盖**：目标已存在 → 停下询问（脚本退出码 3 即此情况）
3. **每步验证**：SHA256 校验、目录列表、git log、聊天库体积等硬指标
4. **遇到错误停下**：报告错误原文与可选方案，不连续重试
5. **脱敏**：密钥内容、服务器 IP、真实用户名不进任何会话输出或打包清单

## 两句话流程

### 第一句（旧设备）：「我要换电脑，帮我打包 Trae 数据」

1. 问最少必要信息：项目路径；是否用过 TRAE SOLO 与 Trae CN 两个客户端（决定是否 `--solo` 双库打包）
2. 跑打包脚本（自动产出五件套 + SHA256 清单）：
   - macOS/Linux：`bash <skill目录>/scripts/pack.sh --project <项目路径> [--solo]`
   - Windows：`powershell <skill目录>\scripts\pack.ps1 -Project <项目路径> [-Solo]`
3. 向用户汇报：包位置、体积、传输方式建议（AirDrop/U盘/网盘），并强调迁移包含密钥与聊天记录，走可信通道
4. 用户手动传输——这是全程唯一的手动环节

### 第二句（新设备）：「迁移包在 <路径>，帮我恢复」

前置：新设备已装好 Trae 并登录一次。然后：

1. 跑恢复脚本（校验 → 恢复项目 → 备份并并入配置 → 密钥权限 600 → 清 git proxy/autocrlf → 解压聊天库到 work/ → 自动生成 migration-job.json）：
   - macOS/Linux：`bash <skill目录>/scripts/restore.sh --dir <迁移包目录>`
   - Windows：`powershell <skill目录>\scripts\restore.ps1 -Dir <迁移包目录>`
2. 退出码 3（目标项目已存在）：问用户「复用/备份后替换/换位置」后带对应参数重跑
3. **装依赖**：脚本不做（项目相关）。Node 20+ 与源端一致，装完启动应用验证健康检查；`.env` 指向旧内网库时给「本地库 + prisma migrate deploy」与「SSH 隧道只读」两方案（默认推荐前者）
4. **记忆挂接**（最易漏）：在目标端 Trae 打开项目让 AI 响应一次触发记忆目录生成 → `ls` 找到新旧编码文件夹（规则见 references/data-locations.md §2.2）→ 合并 `project_memory.md` 与日期目录（不覆盖目标端已有日期）→ 让 AI 复述关键约束请用户确认
5. **聊天迁移**（唯一需确认的写入）：脚本已生成 `work/migration-job.json`（source/target/migrationId 已填好）→ 向用户确认 → 复制到 target 应用数据根目录 → deeplink 触发（macOS `open` / Windows `start ""`，migrationId 与 json 一致）→ 验证「库体积显著增长 + 历史面板可见旧对话」。细节与排障见 references/chat-migration.md
6. **验收**：按 references/chat-migration.md §验收清单逐项打勾；删 migration-job.json 与 work/；旧端迁移包保留 1-2 周再删

## 降级路径

脚本不可用/执行失败时，按 references/data-locations.md §3 的手动命令序列执行，流程与铁律不变。注意部分 AI 沙箱无法写 `~/.trae-cn` 等受保护目录——此时把完整命令交给用户在系统终端执行（见 references/pitfalls.md §2）。

## 排障

先查 references/pitfalls.md（实测 9 类坑）；聊天迁移问题查 references/chat-migration.md 排障表；仍无法解决再看目标端 Trae logs 目录最新 main.log。
