# Сборка веб-версии и выкладка на GitHub Pages (gedekey.github.io/kosti-krakena).
#   powershell -ExecutionPolicy Bypass -File tools\export_web.ps1 [-Deploy]
# Пресет «Web» без потоков: GitHub Pages не отдаёт заголовки COOP/COEP.
# build\web — отдельный git-репозиторий (ветка main → GitHub Pages).
# Сетевая игра (ENet/LAN) в браузере не работает.

param([switch]$Deploy)

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

$out = Join-Path $projectDir "build\web"
New-Item -ItemType Directory -Force $out | Out-Null
$html = Join-Path $out "index.html"

& $godot --headless --path $projectDir --import | Out-Null
& $godot --headless --path $projectDir --export-release "Web" $html
if ($LASTEXITCODE -ne 0 -or -not (Test-Path $html)) { Write-Error "Экспорт не удался" }
New-Item -ItemType File -Force (Join-Path $out ".nojekyll") | Out-Null
Get-ChildItem $out | Select-Object Name, Length

if ($Deploy) {
    Push-Location $out
    git add -A
    git commit -m "Обновление веб-сборки"
    git push origin main
    Pop-Location
}
