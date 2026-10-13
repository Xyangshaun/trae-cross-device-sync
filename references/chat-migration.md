# 逐字聊天库迁移（官方 migration 通道）

> 原理：Trae 启动/收到 deeplink 时，读取应用数据根目录的 `migration-job.json`，把 `source` 指向的旧数据合并进 `target`。该机制原用于官方 SOLO→Trae CN 数据合并，但 source 路径写在 json 里，可指向任意位置的旧数据包。实测：246MB 原始库成功并入，历史对话全部可见。

## 前置条件

- 目标端 Trae 已安装并登录
- 旧端应用数据包已解压到临时目录，且其中存在 `ModularData/ai-agent/database.db`（+`-wal`/`-shm`）
- 向用户确认后再动手（本流程会写入目标端应用数据目录）

## 步骤

1. **找模板**：旧数据包内若有现成 `migration-job.json`，以其为模板；没有则用 assets/migration-job.template.json
2. **改写字段**：

   | 字段 | 改成 |
   |------|------|
   | source | 临时解压目录中旧客户端数据目录的**绝对路径**（含空格需正确转义） |
   | target | 本机 Trae 应用数据目录的绝对路径 |
   | status | `"pending"` |
   | removeApp | `false` |
   | migrationId | 保持模板 UUID，或用 `uuidgen` 新生成——**json 与 deeplink 必须一致** |

3. **备份 target**：整目录复制加日期后缀，如 `Trae CN.bak-YYYYMMDD`
4. **写入**：把改写后的 json 放到 target 应用数据根目录
5. **触发**：
   - macOS：`open "trae-cn://migration?migrationId=<UUID>"`
   - Windows：`start "" "trae-cn://migration?migrationId=<UUID>"`
6. **观察**：Trae 弹出迁移窗口；若停在等待状态，点「开始迁移」或完全退出后重启 Trae（会重读 pending）再触发
7. **验证硬指标**：
   - 聊天库体积显著增长（实测案例 8.5MB → 1.4GB）
   - 聊天历史面板可见旧设备对话原文
8. **清理**：删除写入的 migration-job.json 与临时解压目录

## 多客户端注意

TRAE SOLO 与 Trae CN 的聊天库**分库存放**。若旧端两个都有聊天数据，各自作为 source 各执行一次迁移。

## 排障

| 症状 | 处理 |
|------|------|
| deeplink 无反应 | 确认 json 已写入 target 根目录、migrationId 两处一致；完全退出 Trae 后先启动 Trae 再触发 |
| 窗口弹出但不开始 | 手动点开始；或重启 Trae 重读 pending |
| 迁移中断报错 | 看应用数据目录下 `logs/<最新日期>/main.log`，搜 `migration` |
| 库体积没变 | source 路径写错；或 source 里没有 `ModularData/ai-agent/database.db` |
| 部分会话缺失 | 旧端数据分库，另一个客户端的库也要迁移 |

## 验收清单（整个迁移项目通用）

- [ ] 项目目录完整，git log 最新提交与旧端一致
- [ ] git proxy 已清理、core.autocrlf=false
- [ ] 记忆/skills/plugins/mcps/design_libraries 在位
- [ ] 项目记忆已挂接新编码文件夹（AI 能复述关键约束）
- [ ] 密钥在位且权限收紧（macOS 600）
- [ ] 依赖装完，应用可启动，健康检查通过
- [ ] 聊天库体积增长，历史面板可见旧对话
- [ ] migration-job.json 已删除、临时目录已清理
- [ ] 旧端迁移包保留 1-2 周再删
