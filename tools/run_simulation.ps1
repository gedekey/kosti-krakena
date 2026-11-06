# Симуляция матчей бот против бота: винрейты, стиль жульничества и обвинений, абляция трюков (М3, М6).
#   powershell -ExecutionPolicy Bypass -File tools\run_simulation.ps1
#   powershell -ExecutionPolicy Bypass -File tools\run_simulation.ps1 --duels=500 --tables=5000 --players=4 --ablation=400 --seed=1
# Путь к Godot (консольная сборка) берётся из $env:GODOT, иначе — стандартное место установки.

$ErrorActionPreference = "Stop"
$projectDir = Split-Path -Parent $PSScriptRoot

$godot = $env:GODOT
if (-not $godot) {
    $godot = Get-ChildItem "$env:LOCALAPPDATA\Programs\Godot" -Filter "Godot_v4*_console.exe" -ErrorAction SilentlyContinue |
        Sort-Object Name -Descending | Select-Object -First 1 -ExpandProperty FullName
}
if (-not $godot -or -not (Test-Path $godot)) {
    Write-Error "Godot не найден. Укажите путь: `$env:GODOT = 'C:\path\Godot_v4.x_console.exe'"
}

& $godot --headless --path $projectDir --import | Out-Null

& $godot --headless --path $projectDir -s res://tools/simulate.gd -- @args
exit $LASTEXITCODE
