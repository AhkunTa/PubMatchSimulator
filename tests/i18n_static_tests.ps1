$ErrorActionPreference = "Stop"

function Assert-FileExists($Path) {
    if (-not (Test-Path -LiteralPath $Path)) {
        throw "Missing file: $Path"
    }
}

function Assert-Contains($Path, $Pattern) {
    $text = Get-Content -Raw -Encoding utf8 -LiteralPath $Path
    if ($text -notmatch $Pattern) {
        throw "Missing pattern '$Pattern' in $Path"
    }
}

Assert-FileExists "scripts\i18n.gd"
Assert-FileExists "data\i18n\zh.json"
Assert-FileExists "data\i18n\en.json"

Assert-Contains "project.godot" 'I18n="\*res://scripts/i18n.gd"'
Assert-Contains "scripts\i18n.gd" "func msg"
Assert-Contains "scripts\i18n.gd" "func msgf"
Assert-Contains "scripts\i18n.gd" 'DEFAULT_LOCALE := "zh"'
Assert-Contains "data\i18n\zh.json" '"ui.route.title"'
Assert-Contains "data\i18n\en.json" '"ui.route.title"'
Assert-Contains "data\i18n\zh.json" '"card.attack_push.name"'
Assert-Contains "data\i18n\en.json" '"card.attack_push.name"'

$scriptFiles = @(
    "scenes\match\route_map.gd",
    "scenes\match\encounter.gd",
    "scripts\encounter_resolver.gd",
    "scripts\run_state.gd"
)

$forbidden = @(
    "Route Select",
    "Choose the next move",
    "Encounter",
    "Strong Push",
    "Scramble Loot",
    "Follow me!",
    "Threat",
    "Cohesion",
    "Result",
    "Confirm Route",
    "Back To Route"
)

$errors = @()
foreach ($file in $scriptFiles) {
    $text = Get-Content -Raw -Encoding utf8 -LiteralPath $file
    foreach ($word in $forbidden) {
        $escaped = [regex]::Escape($word)
        if ($text -match "(\.text|text)\s*=\s*`"[^`"]*$escaped[^`"]*`"") {
            $errors += "$file contains hardcoded UI text: $word"
        }
    }
}

if ($errors.Count -gt 0) {
    throw "I18n static checks failed:`n$($errors -join "`n")"
}

Write-Host "OK: i18n static checks passed"
