# Сборка релизного .exe для Windows (М15).
#   powershell -ExecutionPolicy Bypass -File tools\export_windows.ps1 [-Debug]
# Нужны шаблоны экспорта Godot той же версии (%APPDATA%\Godot\export_templates\4.x.y.stable).
# Результат: build\windows\KostiKrakena.exe (один файл, .pck встроен).

param([switch]$Debug)

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

$out = Join-Path $projectDir "build\windows"
New-Item -ItemType Directory -Force $out | Out-Null
$exe = Join-Path $out "KostiKrakena.exe"

& $godot --headless --path $projectDir --import | Out-Null
$mode = if ($Debug) { "--export-debug" } else { "--export-release" }
& $godot --headless --path $projectDir $mode "Windows Desktop" $exe
if ($LASTEXITCODE -ne 0 -or -not (Test-Path $exe)) { Write-Error "Экспорт не удался" }
Get-Item $exe | Select-Object Name, Length, LastWriteTime
