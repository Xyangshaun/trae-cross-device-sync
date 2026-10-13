# 实测踩坑手册（Win→Mac，按出现顺序）

1. **Node/Brew 安装网络超时**
   换国内镜像源安装 Homebrew；`brew install node@20` 后按安装提示把 PATH 写入 shell 配置并 `source`。

2. **AI 助手沙箱权限限制**
   AI 无法写 `~/.trae-cn` 等受保护目录属正常保护——此类操作让用户在系统终端手动执行，AI 给出完整命令。

3. **git 遗留 Windows 配置**
   `http.proxy`/`https.proxy` 残留导致新网络环境异常；`core.autocrlf` 必须设回 `false`，否则 diff 全文件变动。

4. **私钥权限过松**
   SSH 直接拒绝使用：`chmod 600`。

5. **依赖装完后启动报数据库连不上**
   旧 `.env` 指向旧服务器内网地址。提供两方案：本地库（推荐，`prisma migrate deploy` 建表 + 可选只读 pg_dump 快照导入）或 SSH 隧道只读临时用。绝不建议长期直连生产库开发。

6. **记忆文件夹不出现**
   只打开项目不触发 AI 不会生成记忆目录。在项目里让 AI 响应一次即可。

7. **migration 窗口弹出但不自动开始**
   窗口内可能有确认按钮，手动点；或完全退出 Trae 重启（重新读取 pending 状态）。

8. **迁移后功能开关丢失**
   若项目把功能开关放在 Redis（如 `config:feature:*`），本地 Redis 为空属预期，按需重建；AI 功能类开关通常 fail-closed，先跟用户确认再开。

9. **双端并用期间记忆分叉**
   迁移是快照同步。日常跨设备建议「一端为主」，或定期重跑记忆/配置增量打包（只打 `.trae-cn/memory` 与变更文件）。
