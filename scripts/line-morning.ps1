# 毎朝、その日の勉強の計画（plan/YYYY-MM-DD.json）を LINE 公式アカウントから送る。
# GitHub Actions（.github/workflows/line-morning.yml）が毎朝 6 時ごろに動かす。
# 手元で文面だけ見る：powershell -ExecutionPolicy Bypass -File scripts\line-morning.ps1 -DryRun -Date 2026-11-25
param([string]$Date, [switch]$DryRun)
$ErrorActionPreference = 'Stop'

$jst = [DateTime]::UtcNow.AddHours(9)
if ($Date) { $jst = [DateTime]::ParseExact($Date, 'yyyy-MM-dd', $null) }
$key = $jst.ToString('yyyy-MM-dd')
$wd = @('日', '月', '火', '水', '木', '金', '土')[[int]$jst.DayOfWeek]
$head = '{0}/{1}（{2}）' -f $jst.Month, $jst.Day, $wd

$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$file = Join-Path (Join-Path $root 'plan') ($key + '.json')
$app = 'https://monja-code.github.io/monja-stadium/'

$lines = New-Object System.Collections.Generic.List[string]
$lines.Add('おはよう！☀ ' + $head + ' の勉強だよ')
if (Test-Path $file) {
  $plan = [IO.File]::ReadAllText($file, [Text.Encoding]::UTF8) | ConvertFrom-Json
  if ($plan.soccer) { $lines.Add('⚽ 今日は練習の日（18:30出発）') }
  $lines.Add('')
  $total = 0
  foreach ($s in $plan.slots) {
    $total += [int]$s.minutes
    $lines.Add(('▶ {0}　{1}：{2}（{3}分）' -f $s.time, $s.subject, $s.title, $s.minutes))
    if ($s.first) { $lines.Add('　→ ' + $s.first) }
  }
  $lines.Add('')
  $lines.Add('合計 ' + $total + '分')
  if ($plan.note) { $lines.Add('📝 ' + $plan.note) }
} else {
  $lines.Add('')
  $lines.Add('今日の計画はまだ入っていません。アプリの自主勉で、苦手な単元を1つやろう。')
}
$lines.Add('')
$lines.Add('終わったら📮でお母さんに送ってね。今日もがんばろう💪')
$lines.Add($app)
$text = $lines -join "`n"

if ($DryRun) { $text; return }

$token = $env:LINE_TOKEN
if (-not $token) { throw 'LINE_TOKEN（チャネルアクセストークン）が設定されていません' }
$body = @{ messages = @(@{ type = 'text'; text = $text }) } | ConvertTo-Json -Depth 5 -Compress
$bytes = [Text.Encoding]::UTF8.GetBytes($body)
Invoke-RestMethod -Method Post -Uri 'https://api.line.me/v2/bot/message/broadcast' `
  -Headers @{ Authorization = 'Bearer ' + $token } -ContentType 'application/json; charset=utf-8' -Body $bytes | Out-Null
'送りました：' + $key
