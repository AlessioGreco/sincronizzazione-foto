# make-icon.ps1 - renders the vector logo (src\wpf.ps1 > New-Logo) to assets\icon.png and assets\icon.ico.
# Run:  powershell -Sta -ExecutionPolicy Bypass -File tools\make-icon.ps1
$script:AppRoot = Split-Path -Parent $PSScriptRoot
. (Join-Path $script:AppRoot "src\wpf.ps1")

$assets = Join-Path $script:AppRoot "assets"
New-Item -ItemType Directory -Force $assets | Out-Null

$sizes = 16, 24, 32, 48, 64, 128, 256
$png = @{}
foreach ($s in $sizes) {
    $p = Join-Path $env:TEMP "sf_icon_$s.png"
    Save-VisualPng (New-Logo $s) $s $p
    $png[$s] = [IO.File]::ReadAllBytes($p)
    Remove-Item $p -Force
}
[IO.File]::WriteAllBytes((Join-Path $assets "icon.png"), $png[256])

# .ico container with PNG-compressed images (Windows Vista and newer)
$ms = New-Object IO.MemoryStream
$bw = New-Object IO.BinaryWriter($ms)
$bw.Write([uint16]0); $bw.Write([uint16]1); $bw.Write([uint16]$sizes.Count)
$offset = 6 + 16 * $sizes.Count
foreach ($s in $sizes) {
    $dim = if ($s -ge 256) { 0 } else { $s }
    $bw.Write([byte]$dim); $bw.Write([byte]$dim); $bw.Write([byte]0); $bw.Write([byte]0)
    $bw.Write([uint16]1); $bw.Write([uint16]32)
    $bw.Write([uint32]$png[$s].Length); $bw.Write([uint32]$offset)
    $offset += $png[$s].Length
}
foreach ($s in $sizes) { $bw.Write($png[$s]) }
$bw.Flush()
[IO.File]::WriteAllBytes((Join-Path $assets "icon.ico"), $ms.ToArray())
Write-Host "Wrote assets\icon.png and assets\icon.ico"
