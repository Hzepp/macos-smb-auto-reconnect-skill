# macOS SMB/NAS 自动重连 Skill

让 Finder 中的 SMB 网盘在断网、切换网络或休眠后自动恢复挂载。使用用户级 LaunchAgent，无需 `sudo`，不修改 `/etc` 或 SIP。

## 安装

```bash
npx skills add https://github.com/Hzepp/macos-smb-auto-reconnect-skill
```

安装后可对 Codex 说：

```text
使用 $sofunny-macos-nas-reconnect 为 smb://user@example.local/share 配置自动重连
```

## 手动使用脚本

先通过 Finder 连接一次共享，并将密码保存到钥匙串。默认执行仅预览：

```bash
./sofunny-macos-nas-reconnect/scripts/manage.sh --url 'smb://user@example.local/share'
```

确认后安装：

```bash
./sofunny-macos-nas-reconnect/scripts/manage.sh --install --url 'smb://user@example.local/share'
```

默认每 30 秒检查一次。连续两次确认会话失效后，任务会普通卸载旧挂载，并在网络恢复后重新连接。

## 卸载

```bash
./sofunny-macos-nas-reconnect/scripts/manage.sh --uninstall --url 'smb://user@example.local/share'
```

卸载任务不会推出当前网盘。URL 中不要包含密码，凭据仅保存在 macOS 钥匙串中。
