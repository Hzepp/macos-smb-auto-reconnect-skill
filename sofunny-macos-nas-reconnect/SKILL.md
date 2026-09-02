---
name: sofunny-macos-nas-reconnect
description: 为 macOS 配置 SMB/NAS 网盘自动重连；适用于 Finder 网盘断线、切换内外网后自动恢复挂载。
metadata:
  version: "1.0.0"
---

# macOS NAS 自动重连

为指定 SMB 共享安装用户级 LaunchAgent。任务定时检查挂载健康状态：连接正常时不操作；挂载残留但会话失效时，连续两次确认后卸载旧挂载；网络恢复后通过钥匙串凭据重新挂载。

## 核心场景

- Finder 中的 SMB 网盘在切换网络、休眠或断网后消失。
- 希望恢复可达网络后自动重新挂载，不重复使用“连接服务器”。
- 无法或不希望修改受系统完整性保护（SIP）的 `/etc/auto_master`。

本 Skill 只处理 macOS SMB 地址。NFS、WebDAV、Windows 和 Linux 客户端不适用。

## 执行流程

1. 获取完整的 `smb://用户名@主机/共享名`。共享名包含空格或中文时优先使用 Finder 已连接条目对应的 URL 编码形式。
2. 确认 URL 不含密码。不得把 `smb://用户:密码@主机/共享` 写入命令、脚本或仓库。
3. 确认用户曾通过 Finder 成功连接，并在钥匙串中保存凭据（Credential）。后台任务不能可靠处理交互式密码框。
4. 先执行预览：

```bash
./scripts/manage.sh --url 'smb://user@example.local/share'
```

5. 说明安装会创建用户级脚本和 LaunchAgent；失效检测连续失败两次后会尝试普通卸载旧挂载。获得用户确认后执行：

```bash
./scripts/manage.sh --install --url 'smb://user@example.local/share'
```

6. 用脚本输出的 label 验证 `launchctl print`，并检查 `mount`。不要为验证而强制断开正在使用的共享。

默认检查间隔为 30 秒。只有用户明确要求时才通过 `--interval` 调整；不得设置低于 15 秒。

## 卸载

卸载会删除该 URL 对应的 LaunchAgent、工作脚本和状态文件。执行前需用户确认：

```bash
./scripts/manage.sh --uninstall --url 'smb://user@example.local/share'
```

卸载自动重连任务不会主动推出当前已挂载的网盘。

## 常见错误处理

- `URL must start with smb://`：补全 SMB URL，不能只传主机名。
- `Password-like user info is not allowed`：移除 URL 中的密码，改用 macOS 钥匙串。
- 恢复网络后未重连：先手动连接一次并保存密码，再运行 `launchctl kickstart -k gui/$(id -u)/<label>`。
- 挂载失效但无法卸载：通常有应用正在使用共享；关闭相关 Finder 窗口或文件后等待下次检查，不要自动使用强制卸载。
- 后台任务存在但不运行：用 `launchctl print gui/$(id -u)/<label>` 查看最后退出码，并核对脚本权限。

## 安全边界

- 安装、更新和卸载属于持久化系统变更，执行前必须获得用户确认。
- 不读取、导出或记录钥匙串密码。
- 不使用 `sudo`，不修改 `/etc`，不关闭 SIP。
- 不自动强制卸载仍被应用占用的共享。
