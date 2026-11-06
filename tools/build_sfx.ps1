# Сборка процедурных звуков и музыки-заглушек (М12) в audio/sfx и audio/music.
#   powershell -ExecutionPolicy Bypass -File tools\build_sfx.ps1 [-Only <имя>]
# Рецепты — audio/sfx_synth.gd и audio/music_synth.gd. Godot — как в run_tests.ps1.

param([string]$Only = "")

$ErrorActionPreference = "Stop"
$projectDir = Split-Path -Parent $PSScriptRoot

$godot = $env:GODOT
if (-not $godot) {
    $godot = Get-ChildItem "$env:LOCALAPPDATA\Programs\Godot" -Filter "Godot_v4*_console.exe" -ErrorAction SilentlyContinue |
        Sort-Object Name -Descending | Select-Object -First 1 -ExpandProperty FullName
}

# Импорт до сборки: на свежем клоне иначе не видны class_name.
& $godot --headless --path $projectDir --import | Out-Null
$extra = @()
if ($Only) { $extra = @("--", "--only=$Only") }
& $godot --headless --path $projectDir -s res://tools/build_sfx.gd @extra
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
& $godot --headless --path $projectDir --import | Out-Null
exit 0
