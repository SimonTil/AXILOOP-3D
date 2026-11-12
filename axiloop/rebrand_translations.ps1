# Replaces the upstream app name in the translated texts by "AXILOOP-3D":
#   - localization/i18n/*/*.po : only the translations (msgstr), never the source texts (msgid)
#   - resources/web/**/*.html : the English fallback texts of the web pages (since OrcaSlicer 2.5.0 the pages get
#     their texts from the program, through the .po files; resources/web/data/text.js is only used if it exists)
# Run it again after every upstream merge. For a conflicting translation or web file, take upstream's version
# first (git checkout --theirs <file>). Running it on files that are already rebranded changes nothing.
#
# Usage (from the repo root): powershell -ExecutionPolicy Bypass -File axiloop\rebrand_translations.ps1

$ErrorActionPreference = 'Stop'
$RepoRoot = Split-Path -Parent $PSScriptRoot
$AppName  = 'AXILOOP-3D'

# Name forms to replace, including spellings used by translators (same list as rebrand() in src/slic3r/GUI/I18N.cpp)
$NamePattern = '(?:OrcaSlicer|Orca Slicer|Orcaslicer|Orca slicer|Orca Dilimleyici)'
# Keep the name when it's glued to a link, path or identifier; the escapes \n, \t and \" count as separators
$Separator = '(?:(?<=\\[nt])|(?<![A-Za-z0-9_/\\.]))'
$NameRegex = New-Object regex ($Separator + $NamePattern + '(?![A-Za-z0-9_/]|\\(?![nt"])|\.(?:com|org|net))')
# Inflected names, replaced first: Czech, Hungarian and Turkish attach case endings to the name.
# The new endings follow the last sound of "AXILOOP-3D" ("de"). Czech leaves the name undeclined.
# Non-ASCII letters are written as character codes, because Windows PowerShell 5.1 reads this file as ANSI.
$DotlessI = [string][char]0x0131
$Apostrophe = "['" + [char]0x2019 + "]"
$TurkishEndings = @{ 'daki' = 'deki'; ($DotlessI + 'n') = 'nin'; $DotlessI = 'yi'; 'da' = 'de'; 'ya' = 'ye'; 'a' = 'ye' }
$FullName = '(?:OrcaSlicer|Orca Slicer|Orca slicer)'
$InflectionRules = @(
    @{ Regex = New-Object regex ($FullName + '(' + $Apostrophe + ')(daki|' + $DotlessI + 'n|' + $DotlessI + '|da|ya|a)(?!\p{L})')
       Replace = [Text.RegularExpressions.MatchEvaluator]{ param($m) $AppName + $m.Groups[1].Value + $TurkishEndings[$m.Groups[2].Value] } },
    @{ Regex = New-Object regex ('Orca slicer' + $DotlessI + '(?!\p{L})'); Replace = "AXILOOP-3D'yi" },
    @{ Regex = New-Object regex ($FullName + '(?:u|a|em)(?!\p{L})'); Replace = 'AXILOOP-3D' },
    @{ Regex = New-Object regex ($FullName + 't(?!\p{L})'); Replace = 'AXILOOP-3D-t' },
    @{ Regex = New-Object regex ($FullName + 'rel(?!\p{L})'); Replace = 'AXILOOP-3D-vel' },
    @{ Regex = New-Object regex ($FullName + 'ben(?!\p{L})'); Replace = 'AXILOOP-3D-ben' },
    @{ Regex = New-Object regex ($FullName + 'be(?!\p{L})'); Replace = 'AXILOOP-3D-be' },
    @{ Regex = New-Object regex ($FullName + 'h[eo]z(?!\p{L})'); Replace = 'AXILOOP-3D-hez' }
)

# Short form "Orca": only replaced in entries whose source text refers to the app itself.
# Source phrases where "Orca" means the app (same list as rebrand() in src/slic3r/GUI/I18N.cpp)
$AppPhrases = @('Orca will ', 'Orca would ', 'Orca can ', 'Orca skips ', 'printer and Orca.', 'starting Orca.')
# Orca's own names: entries that contain one of them are left alone, because translations may spell them differently
$ProtectedNames = @('Orca Cloud', 'OrcaCloud', 'Orca Cube', 'Orca String', 'Orca Tolerance', 'Orca YOLO', 'OrcaSliced',
    'Orca Filament', 'Orca Arena', 'Orca Preset', 'orca_bundle')
$ShortFormRegex = New-Object regex ($Separator + 'Orca(?![A-Za-z0-9_])')

# Source texts (msgid) whose translations keep the upstream name: credits and history in the About dialog
$KeepNameSources = @(
    'is based on PrusaSlicer and BambuStudio',
    'began in that same spirit',
    'Today, OrcaSlicer is the most widely used'
)

$Utf8NoBom = New-Object Text.UTF8Encoding($false)

# Function to replace the app name in a piece of text, and the short form "Orca" if requested.
# Returns the text and the number of replacements.
function Replace-Name([string]$text, [bool]$shortForm = $false) {
    $count = 0
    foreach ($rule in $InflectionRules) {
        $n = $rule.Regex.Matches($text).Count
        if ($n -gt 0) { $text = $rule.Regex.Replace($text, $rule.Replace); $count += $n }
    }
    $n = $NameRegex.Matches($text).Count
    if ($n -gt 0) { $text = $NameRegex.Replace($text, $AppName); $count += $n }
    if ($shortForm) {
        $n = $ShortFormRegex.Matches($text).Count
        if ($n -gt 0) { $text = $ShortFormRegex.Replace($text, $AppName); $count += $n }
    }
    return $text, $count
}

# Function to get the text between the outer quotes of a .po line.
# Returns the quoted text, or an empty string.
function Get-Quoted([string]$line) {
    $first = $line.IndexOf('"'); $last = $line.LastIndexOf('"')
    if ($first -lt 0 -or $last -le $first) { return '' }
    $line.Substring($first + 1, $last - $first - 1)
}

# Function to rebrand the translations (msgstr) of one .po file, keeping its line endings.
# Returns the number of replacements.
function Update-PoFile([string]$path) {
    $text = [IO.File]::ReadAllText($path, $Utf8NoBom)
    $lines = [regex]::Split($text, '(?<=\n)')
    # $msgid holds the source text of the current entry, joined from its quoted lines
    $mode = 'none'; $msgid = ''; $keep = $false; $shortForm = $false; $total = 0
    for ($i = 0; $i -lt $lines.Count; $i++) {
        $line = $lines[$i]
        if ($line -match '^msgctxt ') { $mode = 'ctxt'; $msgid = '' }
        elseif ($line -match '^msgid ') { $mode = 'msgid'; $msgid = Get-Quoted $line }
        elseif ($line -match '^msgid_plural ') { $mode = 'msgid'; $msgid += ' ' + (Get-Quoted $line) }
        elseif ($line -match '^msgstr(\[\d+\])? ') {
            # Decide once per entry whether its translations keep the upstream name; the header entry (empty msgid) is metadata
            if ($mode -ne 'msgstr') {
                $keep = ($msgid -eq '') -or (@($KeepNameSources | Where-Object { $msgid.Contains($_) }).Count -gt 0)
                # The short form is replaced only when the source text refers to the app and names nothing of Orca's own
                $refersToApp = $NameRegex.IsMatch($msgid) -or (@($AppPhrases | Where-Object { $msgid.Contains($_) }).Count -gt 0)
                $hasProtected = @($ProtectedNames | Where-Object { $msgid.Contains($_) }).Count -gt 0
                $shortForm = $refersToApp -and -not $hasProtected
            }
            $mode = 'msgstr'
        }
        elseif ($line -match '^"') { if ($mode -eq 'msgid') { $msgid += Get-Quoted $line } }
        else { $mode = 'none' }

        # Replace only inside the translation lines
        if ($mode -eq 'msgstr' -and -not $keep) {
            $result = Replace-Name $line $shortForm
            $lines[$i] = $result[0]; $total += $result[1]
        }
    }
    if ($total -gt 0) { [IO.File]::WriteAllText($path, ($lines -join ''), $Utf8NoBom) }
    $total
}

# Function to rebrand a web file (JavaScript or HTML) as a whole.
# Returns the number of replacements.
function Update-WebFile([string]$path) {
    $text = [IO.File]::ReadAllText($path, $Utf8NoBom)
    $result = Replace-Name $text
    if ($result[1] -gt 0) { [IO.File]::WriteAllText($path, $result[0], $Utf8NoBom) }
    $result[1]
}

$grand = 0
foreach ($po in Get-ChildItem (Join-Path $RepoRoot 'localization\i18n') -Recurse -Filter *.po) {
    $n = Update-PoFile $po.FullName; $grand += $n
    Write-Host ("{0,5}  {1}" -f $n, $po.FullName.Substring($RepoRoot.Length + 1))
}
$webFiles = @(Get-ChildItem (Join-Path $RepoRoot 'resources\web') -Recurse -Filter *.html)
$textJs = Join-Path $RepoRoot 'resources\web\data\text.js'
if (Test-Path $textJs) { $webFiles += @(Get-Item $textJs) }
foreach ($web in $webFiles) {
    $n = Update-WebFile $web.FullName; $grand += $n
    if ($n -gt 0) { Write-Host ("{0,5}  {1}" -f $n, $web.FullName.Substring($RepoRoot.Length + 1)) }
}
Write-Host "Done: $grand replacements."
