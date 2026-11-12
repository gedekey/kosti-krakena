# Сборка портретов и фонов (М14) и арта кампании (М25), нарисованных кодом в pxl (art/*.px.js).
#   powershell -ExecutionPolicy Bypass -File tools\build_art.ps1 [-Pxl C:\path\to\pxl.js]
# Нужен Node ≥ 22.18 и pxl (навык pxl-pixel-art; по умолчанию ~\.claude\skills\pxl-pixel-art\bin\pxl.js).
# Godot — как в run_tests.ps1.
# Портрет Хоба (М25) — не pxl, а картинка автора: python tools/cut_hob_portrait.py.
# Часть слайдов кампании и карта — тоже картинки автора: tools/import_campaign_art.py (вызывается здесь).
# Шаги: pxl рендерит PNG → копируются в assets/generated/ под именами из ART_PROMPTS.md →
# build_sprites.gd собирает атласы (GeneratedArt приводит к размеру и палитре) → импорт.
# Чтобы заменить картинку своей, положите файл в assets/generated/ и запустите только build_sprites.gd.

param([string]$Pxl = "")

$ErrorActionPreference = "Stop"
$projectDir = Split-Path -Parent $PSScriptRoot

if (-not $Pxl) { $Pxl = Join-Path $env:USERPROFILE ".claude\skills\pxl-pixel-art\bin\pxl.js" }
if (-not (Test-Path $Pxl)) { Write-Error "pxl не найден: $Pxl (укажите -Pxl)" }

$godot = $env:GODOT
if (-not $godot) {
    $godot = Get-ChildItem "$env:LOCALAPPDATA\Programs\Godot" -Filter "Godot_v4*_console.exe" -ErrorAction SilentlyContinue |
        Sort-Object Name -Descending | Select-Object -First 1 -ExpandProperty FullName
}

$out = Join-Path $env:TEMP "kraken_art"
if (Test-Path $out) { Remove-Item -Recurse -Force $out }
foreach ($src in @("portraits.px.js", "backgrounds.px.js")) {
    node $Pxl build (Join-Path $projectDir "art\$src") --out $out --no-preview
    if ($LASTEXITCODE -ne 0) { Write-Error "pxl: $src" }
}

# id персонажа → имя файла из ART_PROMPTS.md (то же в GeneratedArt.PORTRAIT_FILES)
$rename = @{ "plague_cultist" = "cultist"; "deep_one" = "deepone" }
$portraits = Join-Path $projectDir "assets\generated\portraits"
$backgrounds = Join-Path $projectDir "assets\generated\backgrounds"
New-Item -ItemType Directory -Force $portraits, $backgrounds | Out-Null

Get-ChildItem (Join-Path $out "sprites") -Filter "*.png" | ForEach-Object {
    if ($_.BaseName -match '^(.+)_(normal|mad)$') {
        $id = $Matches[1]; $state = $Matches[2]
        if ($rename.ContainsKey($id)) { $id = $rename[$id] }
        Copy-Item $_.FullName (Join-Path $portraits "${id}_$state.png") -Force
    }
}
Get-ChildItem (Join-Path $out "scenes") -Filter "*.png" | ForEach-Object {
    Copy-Item $_.FullName (Join-Path $backgrounds $_.Name) -Force
}

# Кампания (М25): детали уровней, слайды, их спрайты и анимации, карта — в assets/generated/campaign/
# (их берёт CampaignArt как есть: они уже в палитре и нужного размера).
$campaignOut = Join-Path $env:TEMP "kraken_campaign_art"
if (Test-Path $campaignOut) { Remove-Item -Recurse -Force $campaignOut }
node $Pxl build (Join-Path $projectDir "art\campaign.px.js") --out $campaignOut --no-preview
if ($LASTEXITCODE -ne 0) { Write-Error "pxl: campaign.px.js" }
$campaign = Join-Path $projectDir "assets\generated\campaign"
New-Item -ItemType Directory -Force $campaign | Out-Null
foreach ($dir in @("sprites", "scenes", "anims")) {
    Get-ChildItem (Join-Path $campaignOut $dir) -Filter "*.png" -ErrorAction SilentlyContinue | ForEach-Object {
        Copy-Item $_.FullName (Join-Path $campaign $_.Name) -Force
    }
}

# Картинки автора поверх pxl: шторм, скалы, берег, дверь, бар, стойка, карта (М25).
python (Join-Path $projectDir "tools\import_campaign_art.py")
if ($LASTEXITCODE -ne 0) { Write-Error "import_campaign_art.py" }

# Импорт до сборки: иначе новые class_name (GeneratedArt) не видны и Godot зависает на ошибке.
& $godot --headless --path $projectDir --import | Out-Null
& $godot --headless --path $projectDir -s res://tools/build_sprites.gd
if ($LASTEXITCODE -ne 0) { Write-Error "build_sprites.gd" }
& $godot --headless --path $projectDir --import | Out-Null
Write-Host "Арт собран: $portraits, $backgrounds, $campaign"
