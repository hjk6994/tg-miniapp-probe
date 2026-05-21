param(
  [ValidateSet('getMe', 'getUpdates', 'setMenu', 'sendButton', 'sendAddHomeTest', 'deleteMenu', 'createStarsInvoiceLink', 'watchStarsPayments')]
  [string]$Action = 'getMe'
)

$ErrorActionPreference = 'Stop'

$root = Resolve-Path (Join-Path $PSScriptRoot '..')
$envPath = Join-Path $root '.env'

if (-not (Test-Path -LiteralPath $envPath)) {
  Write-Error "Missing .env. Copy .env.example to .env and fill BOT_TOKEN, WEB_APP_URL, and optional CHAT_ID."
}

function Read-DotEnv {
  param([string]$Path)

  $result = @{}
  Get-Content -LiteralPath $Path | ForEach-Object {
    $line = $_.Trim()
    if (-not $line -or $line.StartsWith('#')) { return }

    $parts = $line.Split('=', 2)
    if ($parts.Count -ne 2) { return }

    $key = $parts[0].Trim()
    $value = $parts[1].Trim()
    if (($value.StartsWith('"') -and $value.EndsWith('"')) -or ($value.StartsWith("'") -and $value.EndsWith("'"))) {
      $value = $value.Substring(1, $value.Length - 2)
    }

    $result[$key] = $value
  }

  return $result
}

$config = Read-DotEnv -Path $envPath
$botToken = $config['BOT_TOKEN']
$webAppUrl = $config['WEB_APP_URL']
$chatId = $config['CHAT_ID']
$botUsername = if ($config['BOT_USERNAME']) { $config['BOT_USERNAME'].Trim().TrimStart('@') } else { '' }
$buttonText = if ($config['BUTTON_TEXT']) { $config['BUTTON_TEXT'] } else { 'Open Mini App' }

if (-not $botToken) {
  Write-Error "BOT_TOKEN is required in .env."
}

$apiBase = "https://api.telegram.org/bot$botToken"

function Invoke-Tg {
  param(
    [string]$Method,
    [hashtable]$Body
  )

  $params = @{
    Method = 'Post'
    Uri = "$apiBase/$Method"
  }

  if ($Body) {
    $params['ContentType'] = 'application/json; charset=utf-8'
    $params['Body'] = ($Body | ConvertTo-Json -Depth 10 -Compress)
  }

  return Invoke-RestMethod @params
}

function Add-QueryParam {
  param(
    [string]$Url,
    [string]$Name,
    [string]$Value
  )

  $separator = if ($Url.Contains('?')) { '&' } else { '?' }
  $encodedValue = [System.Uri]::EscapeDataString($Value)

  return "$Url$separator$Name=$encodedValue"
}

switch ($Action) {
  'getMe' {
    Invoke-Tg -Method 'getMe' -Body @{} | ConvertTo-Json -Depth 10
  }

  'getUpdates' {
    Invoke-Tg -Method 'getUpdates' -Body @{ limit = 10; timeout = 0 } | ConvertTo-Json -Depth 20
  }

  'setMenu' {
    if (-not $webAppUrl) {
      Write-Error "WEB_APP_URL is required in .env for setMenu."
    }

    Invoke-Tg -Method 'setChatMenuButton' -Body @{
      menu_button = @{
        type = 'web_app'
        text = $buttonText
        web_app = @{ url = $webAppUrl }
      }
    } | ConvertTo-Json -Depth 10
  }

  'sendButton' {
    if (-not $webAppUrl) {
      Write-Error "WEB_APP_URL is required in .env for sendButton."
    }
    if (-not $chatId) {
      Write-Error "CHAT_ID is required in .env for sendButton. Run getUpdates after sending a message to your bot to find it."
    }

    Invoke-Tg -Method 'sendMessage' -Body @{
      chat_id = $chatId
      text = 'Open the Mini App verification page'
      reply_markup = @{
        inline_keyboard = @(
          @(
            @{
              text = $buttonText
              web_app = @{ url = $webAppUrl }
            }
          )
        )
      }
    } | ConvertTo-Json -Depth 10
  }

  'sendAddHomeTest' {
    if (-not $webAppUrl) {
      Write-Error "WEB_APP_URL is required in .env for sendAddHomeTest."
    }
    if (-not $chatId) {
      Write-Error "CHAT_ID is required in .env for sendAddHomeTest. Run getUpdates after sending a message to your bot to find it."
    }

    $addHomeUrl = Add-QueryParam -Url $webAppUrl -Name 'scene' -Value 'add_home_auto'
    $addHomeUrl = Add-QueryParam -Url $addHomeUrl -Name 'v' -Value ([DateTimeOffset]::UtcNow.ToUnixTimeSeconds().ToString())
    $inlineKeyboard = @(
      @(
        @{
          text = '验证加桌能力'
          web_app = @{ url = $addHomeUrl }
        }
      )
    )

    if ($botUsername) {
      $inlineKeyboard += @(
        @(
          @{
            text = '通过 startapp 打开'
            url = "https://t.me/$botUsername?startapp=add_home_auto"
          }
        )
      )
    }

    Invoke-Tg -Method 'sendMessage' -Body @{
      chat_id = $chatId
      text = "测试添加到桌面能力。点击按钮后，Mini App 会自动定位到 addToHomeScreen 验证区，检查状态，并在可触发时自动调用一次加桌流程；最终确认仍需要用户手动完成。"
      reply_markup = @{
        inline_keyboard = $inlineKeyboard
      }
    } | ConvertTo-Json -Depth 10
  }

  'deleteMenu' {
    Invoke-Tg -Method 'setChatMenuButton' -Body @{
      menu_button = @{ type = 'default' }
    } | ConvertTo-Json -Depth 10
  }

  'createStarsInvoiceLink' {
    Invoke-Tg -Method 'createInvoiceLink' -Body @{
      title = 'LuxiaoQ 100 Stars Test'
      description = 'Test payment from Telegram Mini App. Amount: 100 Stars.'
      payload = 'stars_100_' + [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
      currency = 'XTR'
      prices = @(
        @{
          label = '100 Stars'
          amount = 100
        }
      )
    } | ConvertTo-Json -Depth 10
  }

  'watchStarsPayments' {
    $offset = 0
    Write-Host 'Watching pre_checkout_query and successful_payment updates. Press Ctrl+C to stop.'

    while ($true) {
      $updates = Invoke-Tg -Method 'getUpdates' -Body @{
        offset = $offset
        timeout = 25
        allowed_updates = @('message', 'pre_checkout_query')
      }

      foreach ($update in $updates.result) {
        $offset = [int64]$update.update_id + 1

        if ($update.pre_checkout_query) {
          $query = $update.pre_checkout_query
          Write-Host "Approving pre_checkout_query $($query.id), payload=$($query.invoice_payload), amount=$($query.total_amount) $($query.currency)"
          Invoke-Tg -Method 'answerPreCheckoutQuery' -Body @{
            pre_checkout_query_id = $query.id
            ok = $true
          } | ConvertTo-Json -Depth 10
        }

        if ($update.message -and $update.message.successful_payment) {
          $payment = $update.message.successful_payment
          Write-Host "Successful payment: payload=$($payment.invoice_payload), amount=$($payment.total_amount) $($payment.currency), charge_id=$($payment.telegram_payment_charge_id)"
        }
      }
    }
  }
}
