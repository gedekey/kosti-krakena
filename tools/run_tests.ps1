# Запуск всех GUT-тестов из консоли.
#   powershell -ExecutionPolicy Bypass -File tools\run_tests.ps1
#   powershell -ExecutionPolicy Bypass -File tools\run_tests.ps1 -gtest=res://tests/unit/test_rng.gd
# Путь к Godot (консольная сборка) берётся из $env:GODOT, иначе — стандартное место установки.
# Код выхода: 0 — все тесты зелёные, иначе — ошибка.

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

# Импорт ресурсов (нужен на свежем клоне, иначе class_name и переводы не видны).
& $godot --headless --path $projectDir --import | Out-Null

& $godot --headless --path $projectDir -s res://addons/gut/gut_cmdln.gd @args
exit $LASTEXITCODE
