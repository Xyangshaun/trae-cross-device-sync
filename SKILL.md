---
name: trae-cross-device-sync
description: 指导把 Trae 上下文完整迁移到另一台设备——项目代码、AI 项目记忆、全局配置、逐字聊天库与密钥，覆盖 Win 转 Mac、Win 转 Win、Mac 转 Mac。当用户提到换电脑、换机、迁移 Trae 数据、同步聊天记录、跨设备同步上下文时使用。不适用于仅用 git 同步代码或常规项目部署的场景。
slug: xyangshaun-trae-cross-device-sync
displayName: Trae 跨设备上下文完整同步
version: 1.0.0
summary: 基于对 Trae 客户端内置官方迁移机制（migration-job.json + deeplink）的逆向与 Win→Mac 实测，把项目代码、AI 项目记忆、全局配置、逐字聊天记录、密钥五类数据完整迁移到新设备，六阶段交互式引导，强制先备份后动手。
license: MIT
---

# Trae 跨设备上下文同步

带领用户完成 Trae 全部上下文（五类数据）在新旧设备间的迁移。这是**交互式流程**：一次只执行一个阶段，每个阶段结束向用户汇报结果并获得确认后再进入下一阶段；任何会覆盖已有目录/文件的操作，必须先询问用户。

## 铁律（每个阶段都适用）

1. **先备份后动手**：目标端任何将被写入的既有目录，先做带日期后缀的备份
2. **不盲目覆盖**：目标已存在 → 停下询问用户（复用/备份后替换/跳过）
3. **每步验证**：用可观察的硬指标（目录列表、文件体积、git log）确认成功才前进
4. **遇到错误停下**：向用户报告错误原文与可选方案，不要连续重试
5. **脱敏**：全程不把密钥内容、服务器 IP、真实用户名写进任何会话输出或打包清单

## 五类数据与迁移策略

| 数据 | 策略 | 详见 |
|------|------|------|
| 1 项目代码（含 .git） | tar 打包 → 解压 → git log 验证 | references/data-locations.md §3 |
| 2 AI 项目记忆 | 打包旧编码文件夹 → 新端触发生成后**合并内容** | references/data-locations.md §2.2 |
| 3 全局配置（skills/plugins/mcps） | 打包（剔除目标平台无法运行的平台专用项）→ 放置 | references/data-locations.md §2.1 |
| 4 逐字聊天库（加密 SQLite） | **必须走官方 migration 通道**，禁止直接覆盖库文件 | references/chat-migration.md |
| 5 密钥与环境 | 单独打包、可信通道传输、用后清理 | — |

## 阶段流程

### P0 评估（必做）
1. 问清：源平台（Win/Mac）、目标平台（Win/Mac）、目标端 Trae 是否已安装登录、是否用过 TRAE SOLO 与 Trae CN 两个客户端
2. 按平台列出源端要打包的位置（references/data-locations.md §2.1 对照表），让用户 `ls` 确认数据都在、估算体积
3. 输出迁移计划（打包清单 + 恢复步骤 + 预计耗时），经用户确认

### P1 源端打包
按 references/data-locations.md §3 的命令序列执行（源平台选对应命令组）。要点：
- 打包前关闭 Trae
- 生成 SHA256 清单并让用户核对传输完整性
- 强烈建议让 AI 先把项目历史整理成一份人类可读的 Markdown 日志（认知层备份）

### P2 目标端恢复（项目/配置/依赖）
- 项目解压 → `git log --oneline -1` 核对最新提交
- 配置放置前先备份目标端 `~/.trae-cn`（或 `%USERPROFILE%\.trae-cn`）
- 清理跨平台遗留：git proxy、`core.autocrlf=false`、私钥 `chmod 600`
- 装依赖（Node 20+ 与源端一致），启动应用并验证健康检查
- 若 `.env` 指向旧服务器内网数据库：提供「本地库 + prisma migrate deploy +（可选）只读 pg_dump 快照」与「SSH 隧道只读」两方案让用户选；默认推荐前者

### P3 记忆挂接（最易漏，必须单独做）
1. 让用户在目标端用 Trae 打开项目，对 AI 随便发一条消息，触发记忆文件夹生成（哈希后缀无法凭空构造，必须让 Trae 自己生成）
2. `ls` 记忆根目录找到新旧两个编码文件夹（规则见 references/data-locations.md §2.2）
3. 把 `project_memory.md` 与各日期目录**合并**进新文件夹（不覆盖目标端已有日期目录）
4. 让 AI 读一遍 project_memory.md 复述关键约束，用户确认

### P4 逐字聊天迁移（可选实验，成败不影响 P1-P3）
严格按 references/chat-migration.md 执行。核心：改写 migration-job.json（source 指向旧数据解压目录、target 指向本机 Trae 应用数据目录、status=pending、removeApp=false）→ 备份 target → 写入 → deeplink 触发（migrationId 与 json 一致）→ 用「聊天库体积显著增长 + 历史面板可见旧对话」验证 → 清理。**执行前必须向用户确认。**

### P5 验收与清理
按 references/chat-migration.md §验收清单逐项打勾；删除 migration-job.json 与临时解压目录；提醒用户旧设备迁移包保留 1-2 周再删。

## 排障

遇到问题时先查 references/pitfalls.md（实测 9 类坑），仍无法解决再看目标端 Trae logs 目录最新 main.log。
