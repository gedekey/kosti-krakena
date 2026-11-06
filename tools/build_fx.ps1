# Сборка листов эффектов стола (М10) из библиотеки pixelfx (MIT, github.com/patch-gg/pixelfx).
#   powershell -ExecutionPolicy Bypass -File tools\build_fx.ps1 [-PixelFx C:\path\to\pixelfx]
# Список эффектов и опции — ui/fx/src/fx_list.json. Нужны Node и git (pixelfx клонируется во временную
# папку, если путь не указан). Godot — как в run_tests.ps1.
# Шаги: pixelfx рендерит листы (PNG + JSON) → build_fx.gd приводит их к палитре и пишет
# ui/fx/*.png и ui/fx/fx_sheets.gd → импорт.

param([string]$PixelFx = "")

$ErrorActionPreference = "Stop"
$projectDir = Split-Path -Parent $PSScriptRoot

if (-not $PixelFx) {
    $PixelFx = Join-Path $env:TEMP "pixelfx"
    if (-not (Test-Path (Join-Path $PixelFx "tools\render.mjs"))) {
        git clone -q https://github.com/patch-gg/pixelfx $PixelFx
    }
}

$godot = $env:GODOT
if (-not $godot) {
    $godot = Get-ChildItem "$env:LOCALAPPDATA\Programs\Godot" -Filter "Godot_v4*_console.exe" -ErrorAction SilentlyContinue |
        Sort-Object Name -Descending | Select-Object -First 1 -ExpandProperty FullName
}

$list = Get-Content (Join-Path $projectDir "ui\fx\src\fx_list.json") -Raw -Encoding UTF8 | ConvertFrom-Json
$raw = Join-Path $env:TEMP "kraken_fx_raw"
if (Test-Path $raw) { Remove-Item -Recurse -Force $raw }

foreach ($p in $list.effects.PSObject.Properties) {
    $name = $p.Name
    # PowerShell 5.1 съедает кавычки в аргументах внешних программ — экранируем.
    $opts = ($p.Value.opts | ConvertTo-Json -Compress -Depth 5) -replace '"', '\"'
    $out = Join-Path $raw $name
    Push-Location $PixelFx
    node tools/render.mjs $p.Value.id --sheet --no-actor --fps $list.fps --out $out --opts $opts
    Pop-Location
    if ($LASTEXITCODE -ne 0) { Write-Error "pixelfx: $name" }
}

& $godot --headless --path $projectDir -s res://tools/build_fx.gd -- "--raw=$raw"
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
& $godot --headless --path $projectDir --import | Out-Null
exit 0
