param(
  [ValidateSet('getMe', 'getUpdates', 'setMenu', 'sendButton', 'deleteMenu')]
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

  'deleteMenu' {
    Invoke-Tg -Method 'setChatMenuButton' -Body @{
      menu_button = @{ type = 'default' }
    } | ConvertTo-Json -Depth 10
  }
}
