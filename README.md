# trae-cross-device-sync

Trae 跨设备上下文完整同步 Skill —— 让 AI 带你把 **项目代码、AI 项目记忆、全局配置、逐字聊天记录、密钥** 五类数据完整迁移到新电脑。

> 实测背书：Windows → Mac 全链路迁移成功，246MB 加密聊天库（1500+ 轮历史对话）完整恢复。

## 为什么需要它

- 换电脑后 Trae 的聊天记录、AI 记忆默认不会跟随账号走
- 逐字聊天库是加密 SQLite，直接拷贝无效
- 官方没有公开的跨设备迁移文档，社区普遍认为"做不到"

本 Skill 基于对 Trae 客户端内置官方迁移机制（migration-job.json + deeplink）的逆向发现与实测，把它封装成 AI 交互式引导流程。

## 安装

### 方式一：Trae 内上传（推荐）

1. 下载本仓库 zip（Code → Download ZIP）
2. 打开 Trae → 插件市场 → **技能** 页签 → 右上角 **上传技能**
3. 选择 zip 文件 → 确认，安装后自动启用

### 方式二：贴链接让 AI 装

把本仓库地址发给 Trae：

```
帮我安装这个 skill：https://github.com/Xyangshaun/trae-cross-device-sync
```

### 方式三：手动放置

```bash
git clone https://github.com/Xyangshaun/trae-cross-device-sync.git ~/.trae-cn/skills/trae-cross-device-sync
```

## 使用

安装后，在 Trae 里说：

- 「我要换电脑，迁移 Trae 的聊天记录和项目」
- 「帮我做 Trae 跨设备上下文同步」
- 「换机迁移 Trae 数据」

AI 会进入分阶段引导（评估 → 打包 → 恢复 → 记忆挂接 → 聊天迁移 → 验收），全程强制"先备份后动手、覆盖前询问、每步硬指标验证"。

## 覆盖的迁移矩阵

| 方向 | 状态 |
|------|------|
| Windows → Mac | ✅ 实测通过 |
| Windows → Windows | ✅ 支持（同构，聊天库可直拷或走官方通道） |
| Mac → Mac | ✅ 支持 |
| Mac → Windows | ⚠️ 机制对称，待社区实测反馈 |

## 安全与免责

- Skill 内置脱敏铁律：不打包/不输出密钥内容、服务器 IP、真实用户名
- 逐字聊天迁移使用的是 Trae 客户端自带的官方迁移机制，非官方文档公开能力，**Trae 版本更新可能改变其行为**，使用前请先备份
- 请在遵守 Trae 用户协议的前提下使用

## 许可

MIT
