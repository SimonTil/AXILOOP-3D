# Generates the AXILOOP-3D branding images (SVG, PNG, ICO, ICNS) from the master logo.
# Output mirrors the repo layout, so -OutDir can be the repo root. Working files go to the temp folder.
# Requires only Windows PowerShell 5.1 and Microsoft Edge (used headless to render SVG).
#
# Usage (from the repo root):
#   powershell -ExecutionPolicy Bypass -File axiloop\branding\make-branding.ps1 -LogoSvg axiloop\branding\Logo.svg -OutDir .

param(
    [Parameter(Mandatory = $true)][string]$LogoSvg,
    [Parameter(Mandatory = $true)][string]$OutDir
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

$LightColor = '#595757'   # logo colour on light backgrounds
$DarkColor  = '#F2F2F2'   # off-white logo colour on dark backgrounds (dark mode); not in the app's dark-mode colour swap table
$IconBg     = '#E9E9E9'   # rounded-square background behind the icon symbol

$Edge = "${env:ProgramFiles(x86)}\Microsoft\Edge\Application\msedge.exe"
if (-not (Test-Path $Edge)) { $Edge = "$env:ProgramFiles\Microsoft\Edge\Application\msedge.exe" }
$Inv  = [Globalization.CultureInfo]::InvariantCulture

$OutDir     = [IO.Path]::GetFullPath($OutDir)
$LogoSvg    = [IO.Path]::GetFullPath($LogoSvg)
$WorkDir    = Join-Path ([IO.Path]::GetTempPath()) 'axiloop-branding'
$ImagesDir  = Join-Path $OutDir 'resources\images'
$WebImgDir  = Join-Path $OutDir 'resources\web\image'
foreach ($dir in $WorkDir, $ImagesDir, $WebImgDir) { New-Item -ItemType Directory -Force $dir | Out-Null }

# Function to format a number for SVG output, independent of the Windows locale.
# Returns the number as a string with a dot as decimal separator.
function N([double]$value) { $value.ToString('0.###', $Inv) }

# Function to run headless Edge once with a fresh profile and wait until it finishes or times out.
# Returns $true if Edge exited normally, $false if it hung or failed.
function Invoke-Edge([string[]]$arguments, [int]$timeoutSeconds = 45) {
    # Use a new profile per launch, so a half-closed earlier instance cannot block this one
    $profileDir = Join-Path $WorkDir ('edge-profile-' + [guid]::NewGuid().ToString('N').Substring(0, 8))
    # Disable background services (component updater, extensions), which can stall headless Edge
    $common = @('--headless=new', '--disable-gpu', '--no-first-run', '--no-default-browser-check', '--hide-scrollbars',
        '--disable-extensions', '--disable-component-update', '--disable-background-networking', '--disable-sync',
        "--user-data-dir=$profileDir")
    $p = Start-Process -FilePath $Edge -ArgumentList ($common + $arguments) -PassThru -WindowStyle Hidden `
        -RedirectStandardOutput (Join-Path $WorkDir 'edge-out.txt') -RedirectStandardError (Join-Path $WorkDir 'edge-err.txt')
    # Cache the process handle, otherwise Windows PowerShell 5.1 cannot read the exit code later
    $null = $p.Handle
    $ok = $p.WaitForExit($timeoutSeconds * 1000)
    if (-not $ok) {
        # Stop only this Edge instance and its child processes
        & taskkill.exe /PID $p.Id /T /F | Out-Null
        $p.WaitForExit()
        Write-Host "Edge timed out after $timeoutSeconds s and was stopped."
    }
    elseif ($p.ExitCode -ne 0) {
        Write-Host "Edge exited with code $($p.ExitCode)."
        $ok = $false
    }
    Remove-Item $profileDir -Recurse -Force -ErrorAction SilentlyContinue
    $ok
}

# Function to run headless Edge until it succeeds and the expected output exists, at most a few attempts.
function Invoke-EdgeWithRetry([string[]]$arguments, [scriptblock]$isDone, [int]$attempts = 3) {
    for ($i = 1; $i -le $attempts; $i++) {
        if ((Invoke-Edge $arguments) -and (& $isDone)) { return }
        Write-Host "Edge attempt $i of $attempts failed."
    }
    throw "Edge failed $attempts times in a row."
}

# Split the master logo into the symbol (A with loop) and the "AXILOOP" wordmark.
# Logo.svg layout: one outer <g>; its first child <g> is the wordmark, the remaining children form the symbol.
[xml]$doc = Get-Content -Path $LogoSvg -Raw
$outer = $doc.svg.g
$children = @($outer.ChildNodes | Where-Object { $_.NodeType -eq 'Element' })
$wordmarkNode = $children | Where-Object { $_.LocalName -eq 'g' } | Select-Object -First 1
$symbolNodes = $children | Where-Object { $_ -ne $wordmarkNode }

# Function to serialize logo elements without their CSS class, so the fill comes from the parent group.
# Returns the SVG markup as a string.
function Get-Markup($nodes) {
    ($nodes | ForEach-Object { $_.OuterXml }) -join '' -replace ' class="st0"', '' -replace ' xmlns="http://www.w3.org/2000/svg"', ''
}
$SymbolMarkup = Get-Markup $symbolNodes
$WordmarkMarkup = Get-Markup @($wordmarkNode)

# Measure the bounding boxes of both parts by letting Edge render the original logo
$measureHtml = Join-Path $WorkDir 'measure.html'
$plainSvg = (Get-Content -Path $LogoSvg -Raw) -replace '<\?xml[^>]*\?>', '' -replace '(?s)<!--.*?-->', ''
@"
<!DOCTYPE html><html><body>$plainSvg<pre id="out"></pre><script>
const outer = document.querySelector('svg > g');
const parts = Array.from(outer.children);
const wordmark = parts.find(e => e.tagName === 'g');
const symbol = parts.filter(e => e !== wordmark);
function box(list) {
  let x1 = 1e9, y1 = 1e9, x2 = -1e9, y2 = -1e9;
  for (const e of list) { const b = e.getBBox(); x1 = Math.min(x1, b.x); y1 = Math.min(y1, b.y); x2 = Math.max(x2, b.x + b.width); y2 = Math.max(y2, b.y + b.height); }
  return { X: x1, Y: y1, W: x2 - x1, H: y2 - y1 };
}
document.getElementById('out').textContent = JSON.stringify({ Symbol: box(symbol), Wordmark: box([wordmark]), All: box(parts) });
</script></body></html>
"@ | Set-Content -Path $measureHtml -Encoding UTF8
$domFile = Join-Path $WorkDir 'edge-out.txt'
Invoke-EdgeWithRetry @('--dump-dom', ([Uri]$measureHtml).AbsoluteUri) ({ (Get-Content $domFile -Raw) -match '<pre id="out">' }.GetNewClosure())
$dom = Get-Content $domFile -Raw
if ($dom -notmatch '<pre id="out">(.*?)</pre>') { throw 'Could not measure the logo with Edge.' }
$Boxes = $Matches[1] | ConvertFrom-Json
Write-Host ("Symbol box:   {0}" -f ($Boxes.Symbol | ConvertTo-Json -Compress))
Write-Host ("Wordmark box: {0}" -f ($Boxes.Wordmark | ConvertTo-Json -Compress))

# Function to fit a logo part into a target box, keeping its aspect ratio (centred, or left-aligned).
# Returns an SVG <g> element string.
function Place([string]$markup, $bbox, [string]$color, [double]$x, [double]$y, [double]$w, [double]$h, [switch]$AlignLeft) {
    $s = [Math]::Min($w / $bbox.W, $h / $bbox.H)
    $offsetX = if ($AlignLeft) { 0 } else { ($w - $bbox.W * $s) / 2 }
    $tx = $x + $offsetX - $bbox.X * $s
    $ty = $y + ($h - $bbox.H * $s) / 2 - $bbox.Y * $s
    "<g fill=`"$color`" transform=`"translate($(N $tx) $(N $ty)) scale($(N $s))`">$markup</g>"
}

# Function to wrap SVG content into a complete SVG document.
# Returns the SVG document as a string.
function New-Svg([double]$w, [double]$h, [string]$content) {
    "<?xml version=`"1.0`" encoding=`"UTF-8`"?><svg xmlns=`"http://www.w3.org/2000/svg`" width=`"$(N $w)`" height=`"$(N $h)`" viewBox=`"0 0 $(N $w) $(N $h)`">$content</svg>"
}

# Function to write a text file as UTF-8 without BOM.
function Save-Text([string]$path, [string]$text) { [IO.File]::WriteAllText($path, $text, (New-Object Text.UTF8Encoding($false))) }

# --- SVG sources ---

# App icon: symbol on a light rounded square (same style as the original icon).
# The symbol's largest side is 76% of the canvas, the same proportion as the original icon at every size.
$iconContent = "<rect x=`"16`" y=`"16`" width=`"992`" height=`"992`" rx=`"150`" fill=`"$IconBg`"/>" +
    (Place $SymbolMarkup $Boxes.Symbol $LightColor 123 123 778 778)
$iconSvg = New-Svg 1024 1024 $iconContent
Save-Text (Join-Path $WorkDir 'icon.svg') $iconSvg
Save-Text (Join-Path $ImagesDir 'OrcaSlicer.svg') ($iconSvg -replace 'width="1024" height="1024"', 'width="64" height="64"')

# Symbol only on a transparent background (setup wizard background)
Save-Text (Join-Path $WorkDir 'symbol.svg') (New-Svg 1024 1024 (Place $SymbolMarkup $Boxes.Symbol $LightColor 64 64 896 896))

# About dialog banner (560x125): symbol left, wordmark right, thin line at the bottom.
# Light mode shows the symbol on the icon square; dark mode shows the plain symbol in the dark-mode colour.
foreach ($variant in @(@{ File = 'OrcaSlicer_about.svg'; Color = $LightColor; Square = $true }, @{ File = 'OrcaSlicer_about_dark.svg'; Color = $DarkColor; Square = $false })) {
    $square = if ($variant.Square) { "<rect x=`"20`" y=`"21.22`" width=`"80.56`" height=`"80.56`" rx=`"9.64`" fill=`"$IconBg`"/>" } else { '' }
    $content = $square +
        (Place $SymbolMarkup $Boxes.Symbol $variant.Color 30 31.22 60.56 60.56) +
        (Place $WordmarkMarkup $Boxes.Wordmark $variant.Color 118 47 300 29 -AlignLeft) +
        "<rect x=`"20`" y=`"123`" width=`"520`" height=`"2`" fill=`"$($variant.Color)`"/>"
    Save-Text (Join-Path $ImagesDir $variant.File) (New-Svg 560 125 $content)
}

# Splash screen (480x480): full logo in the upper part, the app draws version text below it
foreach ($variant in @(@{ File = 'splash_logo.svg'; Color = $LightColor }, @{ File = 'splash_logo_dark.svg'; Color = $DarkColor })) {
    Save-Text (Join-Path $ImagesDir $variant.File) (New-Svg 480 480 (Place ($SymbolMarkup + $WordmarkMarkup) $Boxes.All $variant.Color 78 80 324 225))
}

# Horizontal logo (214x80, troubleshoot dialog): symbol left, wordmark right
foreach ($variant in @(@{ File = 'OrcaSlicer_horizontal_light.svg'; Color = $LightColor }, @{ File = 'OrcaSlicer_horizontal_dark.svg'; Color = $DarkColor })) {
    $content = (Place $SymbolMarkup $Boxes.Symbol $variant.Color 6 12 72 56) +
        (Place $WordmarkMarkup $Boxes.Wordmark $variant.Color 88 30 120 20 -AlignLeft)
    Save-Text (Join-Path $ImagesDir $variant.File) (New-Svg 214 80 $content)
}

# --- PNG rendering ---

# Function to render several SVG files side by side in one Edge screenshot (transparent background),
# then cut the screenshot into separate PNG files. Each SVG is still drawn directly at its target size.
function Render-Pngs($jobs) {
    # Place the images next to each other with a small gap
    $gap = 8
    $x = 0
    $tags = foreach ($job in $jobs) {
        $job.X = $x
        "<img src=`"$(([Uri]$job.Svg).AbsoluteUri)`" style=`"position:absolute;left:${x}px;top:0;width:$($job.Size)px;height:$($job.Size)px`">"
        $x += $job.Size + $gap
    }
    $width = $x - $gap
    $height = ($jobs | Measure-Object -Property Size -Maximum).Maximum
    $html = Join-Path $WorkDir 'render.html'
    "<!DOCTYPE html><html><body style=`"margin:0;background:transparent`">$($tags -join '')</body></html>" | Set-Content -Path $html -Encoding UTF8

    # Remove an older screenshot first, so a failed run cannot be mistaken for a new one
    $sheetPng = Join-Path $WorkDir 'render.png'
    if (Test-Path $sheetPng) { Remove-Item $sheetPng -Force }
    Invoke-EdgeWithRetry @('--force-device-scale-factor=1', '--default-background-color=00000000', "--window-size=$width,$height",
        "--screenshot=$sheetPng", ([Uri]$html).AbsoluteUri) ({ Test-Path $sheetPng }.GetNewClosure())

    # Cut each image out of the screenshot
    $sheet = New-Object Drawing.Bitmap $sheetPng
    try {
        if ($sheet.Width -ne $width -or $sheet.Height -ne $height) {
            throw "Screenshot is $($sheet.Width)x$($sheet.Height), expected ${width}x$height."
        }
        foreach ($job in $jobs) {
            $part = $sheet.Clone((New-Object Drawing.Rectangle $job.X, 0, $job.Size, $job.Size), [Drawing.Imaging.PixelFormat]::Format32bppArgb)
            $part.Save($job.Png, [Drawing.Imaging.ImageFormat]::Png)
            $part.Dispose()
        }
    }
    finally { $sheet.Dispose() }
}

$iconPath = Join-Path $WorkDir 'icon.svg'
$Rendered = @{}
$jobs = foreach ($size in 16, 24, 32, 48, 64, 128, 154, 184, 192, 256, 512, 1024) {
    $Rendered[$size] = Join-Path $WorkDir "icon_$size.png"
    [pscustomobject]@{ Svg = $iconPath; Size = $size; Png = $Rendered[$size]; X = 0 }
}
$symbolPng = Join-Path $WorkDir 'symbol_192.png'
Render-Pngs (@($jobs) + [pscustomobject]@{ Svg = (Join-Path $WorkDir 'symbol.svg'); Size = 192; Png = $symbolPng; X = 0 })

# Copy the renders to the file names the app expects
$pngTargets = [ordered]@{
    'OrcaSlicer_32px.png'            = 32
    'OrcaSlicer_64.png'              = 64
    'OrcaSlicer_128px.png'           = 128
    'OrcaSlicer-mac_128px.png'       = 128
    'OrcaSlicer.png'                 = 154
    'OrcaSlicer_154.png'             = 154
    'OrcaSlicerTitle.png'            = 154
    'OrcaSlicer_154_title.png'       = 184
    'OrcaSlicer_192px.png'           = 192
    'OrcaSlicer_192px_grayscale.png' = 192
}
foreach ($name in $pngTargets.Keys) { Copy-Item $Rendered[$pngTargets[$name]] (Join-Path $ImagesDir $name) -Force }
Copy-Item $symbolPng (Join-Path $ImagesDir 'OrcaSlicer_192px_transparent.png') -Force
Copy-Item $Rendered[154] (Join-Path $WebImgDir 'axiloop_logo.png') -Force

# --- ICO packing ---

# Function to convert a PNG into a 32-bit BMP icon entry (BITMAPINFOHEADER + BGRA pixels + AND mask).
# Returns the entry bytes.
function Get-BmpIconEntry([string]$pngPath) {
    $bmp = New-Object Drawing.Bitmap $pngPath
    $w = $bmp.Width; $h = $bmp.Height
    $ms = New-Object IO.MemoryStream
    $bw = New-Object IO.BinaryWriter $ms
    # Header: height is doubled because the AND mask follows the colour data
    $bw.Write([int]40); $bw.Write([int]$w); $bw.Write([int]($h * 2)); $bw.Write([int16]1); $bw.Write([int16]32)
    $bw.Write([int]0); $bw.Write([int]0); $bw.Write([int]0); $bw.Write([int]0); $bw.Write([int]0); $bw.Write([int]0)
    # Colour data, stored bottom-up
    for ($y = $h - 1; $y -ge 0; $y--) {
        for ($x = 0; $x -lt $w; $x++) {
            $c = $bmp.GetPixel($x, $y)
            $bw.Write([byte]$c.B); $bw.Write([byte]$c.G); $bw.Write([byte]$c.R); $bw.Write([byte]$c.A)
        }
    }
    # AND mask: all zero, transparency comes from the alpha channel
    $maskRow = [int]([Math]::Ceiling($w / 32.0) * 4)
    $bw.Write((New-Object byte[] ($maskRow * $h)))
    $bmp.Dispose()
    $bw.Flush()
    $ms.ToArray()
}

# Function to write an .ico file: sizes up to 128 as BMP entries, 256 as a PNG entry.
function Save-Ico([string]$icoPath, [int[]]$sizes) {
    # Cast to byte[] because PowerShell unrolls returned arrays into object[], which BinaryWriter would write as a single byte
    $entries = @(foreach ($size in $sizes) {
        [byte[]]$data = if ($size -ge 256) { [IO.File]::ReadAllBytes($Rendered[$size]) } else { Get-BmpIconEntry $Rendered[$size] }
        [pscustomobject]@{ Size = $size; Data = $data }
    })
    $ms = New-Object IO.MemoryStream
    $bw = New-Object IO.BinaryWriter $ms
    $bw.Write([int16]0); $bw.Write([int16]1); $bw.Write([int16]$entries.Count)
    $offset = 6 + 16 * $entries.Count
    foreach ($e in $entries) {
        $dim = if ($e.Size -ge 256) { 0 } else { $e.Size }
        $bw.Write([byte]$dim); $bw.Write([byte]$dim); $bw.Write([byte]0); $bw.Write([byte]0)
        $bw.Write([int16]1); $bw.Write([int16]32); $bw.Write([int]$e.Data.Length); $bw.Write([int]$offset)
        $offset += $e.Data.Length
    }
    foreach ($e in $entries) { $bw.Write([byte[]]$e.Data) }
    $bw.Flush()
    [IO.File]::WriteAllBytes($icoPath, $ms.ToArray())
}

Save-Ico (Join-Path $ImagesDir 'OrcaSlicer.ico') @(16, 24, 32, 48, 64, 128, 256)
Save-Ico (Join-Path $ImagesDir 'OrcaSlicerTitle.ico') @(16, 24, 32, 48, 64, 128, 256)
Save-Ico (Join-Path $ImagesDir 'OrcaSlicer-mac_256px.ico') @(256)

# --- ICNS packing (macOS app icon) ---

# Function to write a big-endian 32-bit integer, as the ICNS format requires.
function Write-BigEndian([IO.BinaryWriter]$bw, [int]$value) {
    $b = [BitConverter]::GetBytes($value); [Array]::Reverse($b); $bw.Write($b)
}

# Function to write an .icns file from PNG entries (type code and pixel size per entry).
function Save-Icns([string]$icnsPath, $entries) {
    $parts = foreach ($e in $entries) { [pscustomobject]@{ Type = $e.Type; Data = [byte[]][IO.File]::ReadAllBytes($Rendered[$e.Size]) } }
    $total = 8 + ($parts | ForEach-Object { 8 + $_.Data.Length } | Measure-Object -Sum).Sum
    $ms = New-Object IO.MemoryStream
    $bw = New-Object IO.BinaryWriter $ms
    $bw.Write([Text.Encoding]::ASCII.GetBytes('icns')); Write-BigEndian $bw $total
    foreach ($p in $parts) {
        $bw.Write([Text.Encoding]::ASCII.GetBytes($p.Type)); Write-BigEndian $bw (8 + $p.Data.Length); $bw.Write($p.Data)
    }
    $bw.Flush()
    [IO.File]::WriteAllBytes($icnsPath, $ms.ToArray())
}

# PNG-based entry types: ic11-ic14 are the @2x variants of 16, 32, 128 and 256
Save-Icns (Join-Path $ImagesDir 'OrcaSlicer.icns') @(
    @{ Type = 'ic11'; Size = 32 }, @{ Type = 'ic12'; Size = 64 }, @{ Type = 'ic07'; Size = 128 }, @{ Type = 'ic13'; Size = 256 },
    @{ Type = 'ic08'; Size = 256 }, @{ Type = 'ic14'; Size = 512 }, @{ Type = 'ic09'; Size = 512 }, @{ Type = 'ic10'; Size = 1024 })

Write-Host "Done. Output in $OutDir"
