# Сборка APK для Android (М16).
#   powershell -ExecutionPolicy Bypass -File tools\export_android.ps1 [-Debug] [-Install]
# Нужно: шаблоны экспорта Godot той же версии (в них есть android_*.apk), JDK 17 и Android SDK
# (platform-tools, build-tools). Пути к SDK/JDK и debug-ключу — в настройках редактора Godot
# (export/android/*); по умолчанию D:\Android\sdk, D:\Android\jdk17, D:\Android\keys\debug.keystore.
# Релизный ключ — вне репозитория: файл $env:KRAKEN_KEYS (по умолчанию D:\Android\keys\kraken_release.txt)
# со строками keystore=..., alias=..., password=... Пароль в git не попадает.
# Результат: build\android\KostiKrakena.apk (или KostiKrakena-debug.apk). -Install ставит на телефон через adb.

param([switch]$Debug, [switch]$Install)

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

$out = Join-Path $projectDir "build\android"
New-Item -ItemType Directory -Force $out | Out-Null

if ($Debug) {
    $apk = Join-Path $out "KostiKrakena-debug.apk"
    $mode = "--export-debug"
} else {
    $apk = Join-Path $out "KostiKrakena.apk"
    $mode = "--export-release"
    $keys = $env:KRAKEN_KEYS
    if (-not $keys) { $keys = "D:\Android\keys\kraken_release.txt" }
    if (-not (Test-Path $keys)) { Write-Error "Нет файла с релизным ключом: $keys" }
    $cfg = @{}
    foreach ($line in Get-Content $keys) {
        if ($line -match "^\s*(\w+)\s*=\s*(.*)$") { $cfg[$Matches[1]] = $Matches[2].Trim() }
    }
    $env:GODOT_ANDROID_KEYSTORE_RELEASE_PATH = $cfg["keystore"]
    $env:GODOT_ANDROID_KEYSTORE_RELEASE_USER = $cfg["alias"]
    $env:GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD = $cfg["password"]
}

if (Test-Path $apk) { Remove-Item $apk }
& $godot --headless --path $projectDir --import | Out-Null
& $godot --headless --path $projectDir $mode "Android" $apk
if ($LASTEXITCODE -ne 0 -or -not (Test-Path $apk)) { Write-Error "Экспорт не удался" }
Get-Item $apk | Select-Object Name, Length, LastWriteTime

if ($Install) {
    $adb = "D:\Android\sdk\platform-tools\adb.exe"
    if ($env:ANDROID_HOME) { $adb = Join-Path $env:ANDROID_HOME "platform-tools\adb.exe" }
    & $adb install -r $apk
}
