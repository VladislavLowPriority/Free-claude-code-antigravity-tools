<#
.SYNOPSIS
    Интерактивный выбор модели для Claude Code (стрелки + Enter).
    Пишет поле "model" в ~/.claude/settings.json и автоматически переводит
    VS Code в нужный режим (free = прокси Antigravity, sub = подписка Anthropic).
.DESCRIPTION
    Запусти в PowerShell:  .\model-switch.ps1
    ↑/↓ — выбор, Enter — применить, Esc — выход.
#>

$ErrorActionPreference = 'Stop'

# ======================= СПИСОК МОДЕЛЕЙ (редактируй тут) =======================
# Mode: 'free' — gateway-модель через прокси Antigravity (VS Code → free)
#       'sub'  — твоя подписка Anthropic (VS Code → sub)
$Models = @(
    @{ Label = 'Gemini 3.1 Pro Low';  Value = 'anthropic/lmstudio/gemini-3.1-pro-low';  Mode = 'free' }
    @{ Label = 'Gemini 3.1 Pro High'; Value = 'anthropic/lmstudio/gemini-3.1-pro-high'; Mode = 'free' }
    @{ Label = 'Gemini 3 Flash';      Value = 'anthropic/lmstudio/gemini-3-flash';      Mode = 'free' }
    @{ Label = 'Claude Sonnet 4.6';   Value = 'anthropic/lmstudio/claude-sonnet-4-6';   Mode = 'free' }
    @{ Label = 'Claude Opus 4.6';     Value = 'anthropic/lmstudio/claude-opus-4-6';     Mode = 'free' }
    @{ Label = 'Подписка Opus (Anthropic)'; Value = 'opus';                             Mode = 'sub'  }
)
# ===============================================================================

$ClaudeSettings = Join-Path $env:USERPROFILE '.claude\settings.json'
$VsCodeSettings = Join-Path $env:APPDATA 'Code\User\settings.json'

# ----- шаблоны settings.json для VS Code (чистый JSON, без BOM) -----
$VsCodeFree = @'
{
    "http.noProxy": [
        "localhost",
        "127.0.0.1",
        "http://127.0.0.10808"
    ],
    "http.proxySupport": "off",
    "claudeCode.preferredLocation": "panel",
    "claudeCode.environmentVariables": [
        { "name": "ANTHROPIC_BASE_URL", "value": "http://127.0.0.1:8082" },
        { "name": "ANTHROPIC_API_KEY", "value": "freecc" },
        { "name": "CLAUDE_CODE_ENABLE_GATEWAY_MODEL_DISCOVERY", "value": "1" },
        { "name": "CLAUDE_CODE_AUTO_COMPACT_WINDOW", "value": "190000" },
        { "name": "NO_PROXY", "value": "127.0.0.1,localhost" },
        { "name": "HTTP_PROXY", "value": "" },
        { "name": "HTTPS_PROXY", "value": "" },
        { "name": "ALL_PROXY", "value": "" }
    ]
}
'@

$VsCodeSub = @'
{
    "http.noProxy": [
        "localhost",
        "127.0.0.1",
        "http://127.0.0.10808"
    ],
    "http.proxySupport": "override",
    "claudeCode.preferredLocation": "panel",
    "claudeCode.environmentVariables": []
}
'@

function Write-Utf8NoBom([string]$Path, [string]$Text) {
    [System.IO.File]::WriteAllText($Path, $Text, (New-Object System.Text.UTF8Encoding($false)))
}

function Get-CurrentModel {
    if (-not (Test-Path $ClaudeSettings)) { return '(нет файла)' }
    try { return (Get-Content $ClaudeSettings -Raw | ConvertFrom-Json).model } catch { return '(?)' }
}

function Get-VsCodeMode {
    if (-not (Test-Path $VsCodeSettings)) { return 'sub' }
    try {
        $s = Get-Content $VsCodeSettings -Raw | ConvertFrom-Json
        $env = $s.'claudeCode.environmentVariables'
        if ($env -and @($env).Count -gt 0) { return 'free' }
        return 'sub'
    } catch { return 'sub' }
}

function Set-ClaudeModel([string]$Value) {
    $raw = [System.IO.File]::ReadAllText($ClaudeSettings)
    if ($raw -match '"model"\s*:\s*"[^"]*"') {
        $new = [regex]::Replace($raw, '"model"\s*:\s*"[^"]*"', ('"model": "' + $Value + '"'), 1)
    }
    else {
        $new = [regex]::Replace($raw, '\{', ("{`r`n  `"model`": `"$Value`","), 1)
    }
    Write-Utf8NoBom $ClaudeSettings $new
}

function Set-VsCodeMode([string]$Mode) {
    $tpl = if ($Mode -eq 'free') { $VsCodeFree } else { $VsCodeSub }
    Write-Utf8NoBom $VsCodeSettings ($tpl -replace "`r?`n", "`r`n")
}

# ----------------------------- интерактивное меню -----------------------------
function Show-Menu {
    $index = 0
    # стартовая позиция = текущая модель, если найдём
    $cur = Get-CurrentModel
    for ($i = 0; $i -lt $Models.Count; $i++) {
        if ($Models[$i].Value -eq $cur) { $index = $i; break }
    }

    while ($true) {
        Clear-Host
        $curModel = Get-CurrentModel
        $curMode = Get-VsCodeMode
        Write-Host ""
        Write-Host "  Claude Code — выбор модели" -ForegroundColor Cyan
        Write-Host "  ──────────────────────────" -ForegroundColor DarkCyan
        Write-Host "  Сейчас: " -NoNewline -ForegroundColor DarkGray
        Write-Host "$curModel " -NoNewline -ForegroundColor White
        Write-Host "(режим VS Code: $curMode)" -ForegroundColor DarkGray
        Write-Host ""
        for ($i = 0; $i -lt $Models.Count; $i++) {
            $m = $Models[$i]
            $tag = if ($m.Mode -eq 'sub') { '[подписка]' } else { '[free]' }
            if ($i -eq $index) {
                Write-Host ("   > {0,-30} {1}" -f $m.Label, $tag) -ForegroundColor Black -BackgroundColor Cyan
            }
            else {
                Write-Host ("     {0,-30} " -f $m.Label) -NoNewline
                Write-Host $tag -ForegroundColor DarkGray
            }
        }
        Write-Host ""
        Write-Host "  ↑/↓ — выбор   Enter — применить   Esc — выход" -ForegroundColor DarkGray

        $key = [System.Console]::ReadKey($true)
        switch ($key.Key) {
            'UpArrow' { $index = ($index - 1 + $Models.Count) % $Models.Count }
            'DownArrow' { $index = ($index + 1) % $Models.Count }
            'Enter' { return $Models[$index] }
            'Escape' { return $null }
        }
    }
}

$chosen = Show-Menu
Clear-Host
if ($null -eq $chosen) {
    Write-Host "Отменено." -ForegroundColor Yellow
    return
}

$prevMode = Get-VsCodeMode
Set-ClaudeModel $chosen.Value

Write-Host ""
Write-Host "Модель → " -NoNewline; Write-Host $chosen.Label -ForegroundColor Green
Write-Host "  ($($chosen.Value))" -ForegroundColor DarkGray

if ($chosen.Mode -ne $prevMode) {
    Set-VsCodeMode $chosen.Mode
    Write-Host ""
    Write-Host "Режим VS Code: $prevMode → $($chosen.Mode)" -ForegroundColor Cyan
    Write-Host "→ Нужен Reload: Ctrl+Shift+P → 'Developer: Reload Window'" -ForegroundColor Yellow
}
else {
    Write-Host ""
    Write-Host "Готово. Перезагрузи окно VS Code: Ctrl+Shift+P → 'Developer: Reload Window'" -ForegroundColor Yellow
}
Write-Host ""
