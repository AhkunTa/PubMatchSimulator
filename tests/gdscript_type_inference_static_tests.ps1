$ErrorActionPreference = "Stop"

$files = Get-ChildItem -Path "scripts", "scenes" -Recurse -Filter "*.gd" | ForEach-Object { $_.FullName }

$patterns = @(
    ":= .*\.get\(",
    ":= .*\[[^\]]+\]",
    ":= .*duplicate\(",
    ":= EncounterResolver\.resolve_encounter",
    ":= _find_by_id",
    ":= _current_card",
    ":= \["
)

$errors = @()
foreach ($file in $files) {
    $lines = Get-Content -Encoding utf8 -LiteralPath $file
    for ($i = 0; $i -lt $lines.Count; $i++) {
        foreach ($pattern in $patterns) {
            if ($lines[$i] -match $pattern) {
                $errors += "${file}:$($i + 1): $($lines[$i].Trim())"
            }
        }
    }
}

if ($errors.Count -gt 0) {
    throw "Unsafe GDScript type inference patterns found:`n$($errors -join "`n")"
}

Write-Host "OK: no unsafe GDScript type inference patterns found"
