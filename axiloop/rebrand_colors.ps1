# Replaces OrcaSlicer's teal UI accent by the AXILOOP-3D accent (navy blue) in the GUI code
# and the web pages. Only the accent colours listed below are changed; content colours (filament colours,
# G-code preview colours) are left alone. Icons are recoloured at load time in src/slic3r/GUI/BitmapCache.cpp,
# which this script skips on purpose (its replacement keys must keep the teal of the icon files).
# Run it again after every upstream merge. Running it on files that are already recoloured changes nothing.
#
# Usage (from the repo root): powershell -ExecutionPolicy Bypass -File axiloop\rebrand_colors.ps1

$ErrorActionPreference = 'Stop'
$RepoRoot = Split-Path -Parent $PSScriptRoot

# OrcaSlicer accent colour -> AXILOOP-3D accent colour (RRGGBB)
$ColorMap = [ordered]@{
    '009688' = '1F3B73'   # accent (navy)
    '009687' = '3B62AE'   # accent that stays the same in dark mode (links): lighter navy, readable on light and dark
    '009789' = '3B62AE'   # same, About dialog link
    '26A69A' = '2C4F94'   # accent hover
    '00897B' = '172D59'   # accent pressed
    '00675B' = '3B62AE'   # accent in dark mode: lighter, so it stands out on the dark background
    '008172' = '4A71BD'   # accent hover in dark mode
    '52C7B8' = '6F8FD1'   # light accent
    '22BFB0' = '5A80CC'   # focus border, dark
    '00FFD4' = '8AA6E0'   # focus border, light
    'BFE1DE' = 'C8D1E2'   # accent at 25 % on a light background
    'E5F0EE' = 'EAEEF5'   # accent at 10 % on a light background
    '223C3C' = '29354B'   # accent at 25 % on a dark background
    '283232' = '2A2F3B'   # accent at 10 % on a dark background
    '244945' = '26395B'   # selected row, dark
    '00BFA5' = '4A71BD'   # selected row outline, dark
    '00F0D8' = '6F8FD1'   # web accent variants
    '00FFEA' = '8AA6E0'
    '00FFD9' = '7E9BDB'
    '02C7B3' = '3B62AE'
    '4DB6AC' = '6F8FD1'
}

# Integer RGB triples of the same colours, e.g. "0,150,136"
$TripleMap = @{}
foreach ($key in $ColorMap.Keys) {
    $from = '{0},{1},{2}' -f [Convert]::ToInt32($key.Substring(0, 2), 16), [Convert]::ToInt32($key.Substring(2, 2), 16), [Convert]::ToInt32($key.Substring(4, 2), 16)
    $to = $ColorMap[$key]
    $TripleMap[$from] = @([Convert]::ToInt32($to.Substring(0, 2), 16), [Convert]::ToInt32($to.Substring(2, 2), 16), [Convert]::ToInt32($to.Substring(4, 2), 16))
}

# "#RRGGBB" (optionally with alpha) and "0xRRGGBB"
$HexRegex = New-Object regex '(?<prefix>#|0x)(?<rgb>[0-9A-Fa-f]{6})(?<alpha>[0-9A-Fa-f]{2})?(?![0-9A-Fa-f])'
# wxColour(0, 150, 136), IM_COL32(0, 150, 136, 255), rgb(0,150,136), rgba(0, 150, 136, 0.5)
$TripleRegex = New-Object regex '\b(?<fn>wxColour|IM_COL32|ImColor|rgba?)\s*\(\s*(?<r>\d{1,3})\s*,\s*(?<g>\d{1,3})\s*,\s*(?<b>\d{1,3})(?!\s*\.)'
# ImVec4(0.f / 255.f, 150.f / 255.f, 136.f / 255.f, ...), ImVec4(0.0f, 150.f / 255.0f, 136.0f / 255.f, ...)
# and brace initialisers such as {0.0f, 150.f / 255.0f, 136.0f / 255}
$FractionRegex = New-Object regex '(?<open>ImVec4\(|\{)\s*(?<r>\d{1,3})(?:\.0*)?f?(?:\s*/\s*255(?:\.0*)?f?)?\s*,\s*(?<g>\d{1,3})(?:\.0*)?f?\s*/\s*255(?:\.0*)?f?\s*,\s*(?<b>\d{1,3})(?:\.0*)?f?\s*/\s*255(?:\.0*)?f?'
# Integer brace initialisers such as wxColour m_progress_colour = {0, 150, 136};
$BraceTripleRegex = New-Object regex '\{\s*(?<r>\d{1,3})\s*,\s*(?<g>\d{1,3})\s*,\s*(?<b>\d{1,3})\s*(?<close>[,}])'
# ImVec4(0.00f, 0.59f, 0.53f, ...): the accent written as decimals
$DecimalRegex = New-Object regex 'ImVec4\(\s*0\.00?f\s*,\s*0\.59f\s*,\s*0\.53f'

# Strict UTF-8: files in another encoding are skipped instead of being damaged
$StrictUtf8 = New-Object Text.UTF8Encoding($false, $true)
$script:Count = 0

# Function to recolour one file, keeping its encoding and line endings.
# Returns the number of replacements.
function Update-File([string]$path) {
    $bytes = [IO.File]::ReadAllBytes($path)
    $hasBom = $bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF
    $start = if ($hasBom) { 3 } else { 0 }
    try { $text = $StrictUtf8.GetString($bytes, $start, $bytes.Length - $start) }
    catch {
        # Only report files that actually contain an accent colour
        if ([Text.Encoding]::Default.GetString($bytes) -match '(?i)009688|26A69A|0,\s*150,\s*136') { Write-Host "Skipped (not UTF-8): $path" }
        return 0
    }
    $script:Count = 0
    $text = $HexRegex.Replace($text, [Text.RegularExpressions.MatchEvaluator]{ param($m)
        $key = $m.Groups['rgb'].Value.ToUpper()
        if (-not $ColorMap.Contains($key)) { return $m.Value }
        $script:Count++
        $m.Groups['prefix'].Value + $ColorMap[$key] + $m.Groups['alpha'].Value })
    $text = $TripleRegex.Replace($text, [Text.RegularExpressions.MatchEvaluator]{ param($m)
        $key = '{0},{1},{2}' -f [int]$m.Groups['r'].Value, [int]$m.Groups['g'].Value, [int]$m.Groups['b'].Value
        if (-not $TripleMap.ContainsKey($key)) { return $m.Value }
        $script:Count++
        $c = $TripleMap[$key]
        '{0}({1}, {2}, {3}' -f $m.Groups['fn'].Value, $c[0], $c[1], $c[2] })
    $text = $FractionRegex.Replace($text, [Text.RegularExpressions.MatchEvaluator]{ param($m)
        $key = '{0},{1},{2}' -f [int]$m.Groups['r'].Value, [int]$m.Groups['g'].Value, [int]$m.Groups['b'].Value
        if (-not $TripleMap.ContainsKey($key)) { return $m.Value }
        $script:Count++
        $c = $TripleMap[$key]
        '{0}{1}.f / 255.f, {2}.f / 255.f, {3}.f / 255.f' -f $m.Groups['open'].Value, $c[0], $c[1], $c[2] })
    $text = $BraceTripleRegex.Replace($text, [Text.RegularExpressions.MatchEvaluator]{ param($m)
        $key = '{0},{1},{2}' -f [int]$m.Groups['r'].Value, [int]$m.Groups['g'].Value, [int]$m.Groups['b'].Value
        if (-not $TripleMap.ContainsKey($key)) { return $m.Value }
        $script:Count++
        $c = $TripleMap[$key]
        '{{{0}, {1}, {2}{3}' -f $c[0], $c[1], $c[2], $m.Groups['close'].Value })
    $text = $DecimalRegex.Replace($text, [Text.RegularExpressions.MatchEvaluator]{ param($m)
        $script:Count++
        'ImVec4(0.12f, 0.23f, 0.45f' })
    if ($script:Count -gt 0) {
        $out = (New-Object Text.UTF8Encoding($false)).GetBytes($text)
        if ($hasBom) { $out = [byte[]]([byte[]](0xEF, 0xBB, 0xBF) + $out) }
        [IO.File]::WriteAllBytes($path, $out)
    }
    $script:Count
}

# GUI code, except BitmapCache.cpp (see above). The accent ORCA() of the 3D view in src/libslic3r/Color.hpp is set by hand
# (lighter navy #3B62AE, marked AXILOOP-3D), because the 3D view needs a colour that stands out on light and dark backgrounds.
$files = @(Get-ChildItem (Join-Path $RepoRoot 'src\slic3r') -Recurse -Include *.cpp, *.hpp, *.h |
    Where-Object { $_.Name -ne 'BitmapCache.cpp' })
# Web pages, styles and their images (the web pages load SVGs directly), except third-party bundles
$files += @(Get-ChildItem (Join-Path $RepoRoot 'resources\web') -Recurse -Include *.css, *.html, *.js, *.svg |
    Where-Object { $_.FullName -notmatch '\\elegoolink\\' -and $_.Name -notmatch '\.min\.|jquery|swiper' })

$total = 0
foreach ($f in $files) {
    $n = Update-File $f.FullName
    if ($n -gt 0) { $total += $n; Write-Host ("{0,5}  {1}" -f $n, $f.FullName.Substring($RepoRoot.Length + 1)) }
}
Write-Host "Done: $total replacements."
