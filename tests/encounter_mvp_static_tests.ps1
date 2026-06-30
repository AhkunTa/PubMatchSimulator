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

Assert-FileExists "scripts\encounter_resolver.gd"
Assert-FileExists "scenes\match\encounter.tscn"
Assert-FileExists "scenes\match\encounter.gd"

Assert-Contains "scripts\encounter_resolver.gd" "class_name EncounterResolver"
Assert-Contains "scripts\encounter_resolver.gd" "static func get_basic_cards"
Assert-Contains "scripts\encounter_resolver.gd" "static func resolve_encounter"
Assert-Contains "scripts\encounter_resolver.gd" "attack_push"
Assert-Contains "scripts\encounter_resolver.gd" "scramble_loot"
Assert-Contains "scripts\encounter_resolver.gd" "steal_bag"
Assert-Contains "scripts\encounter_resolver.gd" "fallback"

Assert-Contains "scripts\run_state.gd" "encounter_deck"
Assert-Contains "scripts\run_state.gd" "encounter_hand"
Assert-Contains "scripts\run_state.gd" "encounter_log"
Assert-Contains "scripts\run_state.gd" "last_encounter_result"

Assert-Contains "scenes\match\encounter.tscn" "CardButton1"
Assert-Contains "scenes\match\encounter.tscn" "CardButton2"
Assert-Contains "scenes\match\encounter.tscn" "CardButton3"
Assert-Contains "scenes\match\encounter.tscn" "ShoutOption"
Assert-Contains "scenes\match\encounter.tscn" "ResolveButton"
Assert-Contains "scenes\match\encounter.tscn" "ResultLogLabel"

Assert-Contains "scenes\match\encounter.gd" "EncounterResolver.resolve_encounter"
Assert-Contains "scenes\match\encounter.gd" "_render_cards"
Assert-Contains "scenes\match\encounter.gd" "_render_result"

Write-Host "OK: encounter MVP static checks passed"
