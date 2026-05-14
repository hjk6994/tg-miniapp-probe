# Telegram Mini App 能力验证页

这是一个纯静态 Telegram Mini App 验证页，不需要服务器，不包含 bot token。

## 验证能力

- `Telegram.WebApp.requestFullscreen()`
- `Telegram.WebApp.exitFullscreen()`
- `Telegram.WebApp.addToHomeScreen()`
- `Telegram.WebApp.checkHomeScreenStatus()`
- `Telegram.WebApp.enableClosingConfirmation()`
- `Telegram.WebApp.disableClosingConfirmation()`
- `Telegram.WebApp.close()` 前自定义二次确认

## 部署到 GitHub Pages

1. 新建 GitHub 仓库，例如 `tg-miniapp-probe`。
2. 上传本目录中的文件。
3. 打开仓库设置：
   - `Settings`
   - `Pages`
   - `Build and deployment`
   - `Source: Deploy from a branch`
   - `Branch: main`
   - `Folder: /root`
4. 保存后等待 GitHub Pages 生成地址。

生成后的地址通常类似：

```text
https://你的用户名.github.io/tg-miniapp-probe/
```

## 本地 Telegram 配置

先复制配置模板：

```powershell
Copy-Item .env.example .env
```

然后打开 `.env` 填写：

```text
BOT_TOKEN=123456:ABCDEF
WEB_APP_URL=https://你的用户名.github.io/tg-miniapp-probe/
BOT_USERNAME=你的bot用户名
CHAT_ID=
BUTTON_TEXT=Open Mini App
```

字段说明：

- `BOT_TOKEN`：在 `@BotFather` 创建 bot 后拿到的 token。只填在本机 `.env`，不要提交到 GitHub。
- `WEB_APP_URL`：GitHub Pages 生成的 HTTPS 地址。
- `BOT_USERNAME`：bot 用户名，不带 `@`。用于你自己拼测试链接。
- `CHAT_ID`：可选。要用 bot 主动给你或群发 Mini App 按钮时才需要。
- `BUTTON_TEXT`：菜单按钮或消息按钮的显示文案。可以改成中文，例如 `打开验证页`。

`.gitignore` 已经忽略 `.env`，避免误提交 token。

## 配置 Telegram Bot

在 `@BotFather` 中配置你的测试 bot：

1. 发送 `/mybots`
2. 选择你的 bot
3. 进入 `Bot Settings`
4. 进入 `Configure Mini App`
5. 启用 Mini App，并填写 GitHub Pages 的 HTTPS 地址

也可以配置菜单按钮：

```text
/setmenubutton
```

按提示选择 bot，填写按钮文案和 Mini App URL。

也可以用本地脚本配置菜单按钮：

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\tg-miniapp-setup.ps1 setMenu
```

检查 bot token 是否正确：

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\tg-miniapp-setup.ps1 getMe
```

获取最近消息，用来找 `CHAT_ID`：

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\tg-miniapp-setup.ps1 getUpdates
```

给指定 `CHAT_ID` 发送一个带 Mini App 按钮的消息：

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\tg-miniapp-setup.ps1 sendButton
```

## 测试入口

配置 Main Mini App 后，可以用：

```text
https://t.me/你的bot用户名?startapp=test001
```

如果配置了菜单按钮，也可以直接从 bot 会话底部的菜单按钮打开。

## 注意事项

- 需要从 Telegram Mini App 容器里打开，普通浏览器只能看到降级提示。
- `requestFullscreen` 和 `addToHomeScreen` 需要 Telegram Bot API 8.0+ 客户端支持。
- `addToHomeScreen` 不能静默添加，必须由用户确认。
- 页面内的关闭按钮会先调用 `showConfirm`，确认后才调用 `close()`。
- `enableClosingConfirmation()` 用于测试用户尝试手势关闭或点击 Telegram 关闭入口时的官方确认。

官方文档：

- https://core.telegram.org/bots/webapps
- https://core.telegram.org/api/web-events#web-app-add-to-home-screen
