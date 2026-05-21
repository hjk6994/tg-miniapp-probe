# Telegram Mini App 能力验证页

这是一个纯静态的 Telegram Mini App 验证项目，可部署到 GitHub Pages。页面不包含 bot token，所有需要 Bot API 的操作都通过本地 `.env` 和 `scripts/tg-miniapp-setup.ps1` 完成。

## 已支持能力

- `Telegram.WebApp.requestFullscreen()`
- `Telegram.WebApp.exitFullscreen()`
- `Telegram.WebApp.addToHomeScreen()`
- `Telegram.WebApp.checkHomeScreenStatus()`
- `Telegram.WebApp.openInvoice()` 调起 100 Telegram Stars 支付
- `Telegram.WebApp.enableClosingConfirmation()`
- `Telegram.WebApp.disableClosingConfirmation()`
- `Telegram.WebApp.close()` 前自定义二次确认

## GitHub Pages

当前页面可部署为：

```text
https://hjk6994.github.io/tg-miniapp-probe/
```

在 `@BotFather` 中把 Mini App URL 配置为上面的 HTTPS 地址。

## 本地配置

复制配置模板：

```powershell
Copy-Item .env.example .env
```

填写：

```text
BOT_TOKEN=123456:ABCDEF
WEB_APP_URL=https://hjk6994.github.io/tg-miniapp-probe/
BOT_USERNAME=YourBotName
CHAT_ID=
BUTTON_TEXT=Open Mini App
```

`.env` 已被 `.gitignore` 忽略，不要把 bot token 提交到 GitHub。

## 常用 Bot 操作

检查 bot：

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\tg-miniapp-setup.ps1 getMe
```

获取最近消息，用于查 `CHAT_ID`：

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\tg-miniapp-setup.ps1 getUpdates
```

配置菜单按钮：

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\tg-miniapp-setup.ps1 setMenu
```

发送 Mini App 按钮消息：

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\tg-miniapp-setup.ps1 sendButton
```

发送“添加到桌面”验证消息：

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\tg-miniapp-setup.ps1 sendAddHomeTest
```

这条消息会发送一个 Mini App 按钮，打开：

```text
https://hjk6994.github.io/tg-miniapp-probe/?scene=add_home_auto
```

页面会自动滚动到 `addToHomeScreen` 验证区，先检查主屏幕状态；只要状态不是 `added` 或 `unsupported`，就会自动调用一次 `Telegram.WebApp.addToHomeScreen()`。页面也会把 Telegram 底部主按钮设置成“添加到主屏幕”，用于在客户端拦截非用户手势调用时让用户一键补触发。如果 Telegram 或系统要求确认，需要用户手动点击确认；网页无法代替用户完成系统确认。

也可以用 Main Mini App 链接验证启动参数：

```text
https://t.me/LuxiaoQ_bot?startapp=add_home_auto
```

如果只想自动定位，不想页面加载后自动尝试调用加桌，把参数改成：

```text
https://hjk6994.github.io/tg-miniapp-probe/?scene=add_home
```

## Stars 支付测试

页面中包含“支付 100 Stars”按钮。按钮会调用：

```js
Telegram.WebApp.openInvoice(invoiceLink)
```

当前内置发票链接由 Bot API `createInvoiceLink` 生成，金额为 `100 XTR`。Telegram Stars 支付使用 `currency = XTR`，不需要提交 `provider_token`。

如果需要重新生成 100 Stars 发票链接：

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\tg-miniapp-setup.ps1 createStarsInvoiceLink
```

如果要完成真实支付流程，Bot 端必须处理 `pre_checkout_query` 并调用 `answerPreCheckoutQuery`。本地测试时可以运行：

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\tg-miniapp-setup.ps1 watchStarsPayments
```

脚本会轮询更新、自动通过 `pre_checkout_query`，并在收到 `successful_payment` 时输出交易信息。

## 注意事项

- 普通浏览器只能看到降级状态，能力验证应从 Telegram Mini App 容器打开。
- Stars 支付发票可以被调起，但支付成功必须有 Bot 端确认 `pre_checkout_query`。
- `addToHomeScreen` 不能静默添加，必须由用户确认。
- `openInvoice` 会在支付窗口关闭时触发 `invoiceClosed`，状态可能是 `paid`、`cancelled`、`failed` 或 `pending`。

官方文档：

- https://core.telegram.org/bots/webapps
- https://core.telegram.org/bots/payments-stars
- https://core.telegram.org/bots/api#createinvoicelink
