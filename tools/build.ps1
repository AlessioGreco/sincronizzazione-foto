# build.ps1 - builds dist\SincronizzaFoto.exe: ONE file with the whole app inside (no install, no .bat).
# Needs nothing but Windows: it uses the C# compiler that ships with .NET Framework 4.
# Run:  powershell -ExecutionPolicy Bypass -File tools\build.ps1
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$dist = Join-Path $root 'dist'
$zip  = Join-Path $dist 'app.zip'
$exe  = Join-Path $dist 'SincronizzaFoto.exe'

$csc = Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
if (-not (Test-Path $csc)) { $csc = Join-Path $env:WINDIR 'Microsoft.NET\Framework\v4.0.30319\csc.exe' }
if (-not (Test-Path $csc)) { throw 'csc.exe (.NET Framework 4) not found.' }

New-Item -ItemType Directory -Force $dist | Out-Null
Remove-Item $zip, $exe -Force -ErrorAction SilentlyContinue

# 1) pack the app (only what it needs at run time; never personal data)
Add-Type -AssemblyName System.IO.Compression, System.IO.Compression.FileSystem
$items = @('SincronizzaFoto.ps1', 'src', 'lang', 'ui', 'assets', 'docs')
$za = [IO.Compression.ZipFile]::Open($zip, 'Create')
try {
    foreach ($item in $items) {
        $p = Join-Path $root $item
        $files = if ((Get-Item $p).PSIsContainer) { Get-ChildItem $p -Recurse -File } else { Get-Item $p }
        foreach ($f in $files) {
            $rel = $f.FullName.Substring($root.Length + 1).Replace('\', '/')
            [void][IO.Compression.ZipFileExtensions]::CreateEntryFromFile($za, $f.FullName, $rel, 'Optimal')
        }
    }
} finally { $za.Dispose() }

# 2) compile the launcher with the zip embedded
$refs = 'System.Windows.Forms.dll', 'System.IO.Compression.dll', 'System.IO.Compression.FileSystem.dll'
$args = @('/nologo', '/target:winexe', '/optimize+', "/out:$exe",
          "/win32icon:$(Join-Path $root 'assets\icon.ico')",
          "/resource:$zip,app.zip") + ($refs | ForEach-Object { "/reference:$_" }) + (Join-Path $PSScriptRoot 'launcher.cs')
& $csc @args
if ($LASTEXITCODE -ne 0) { throw "csc failed ($LASTEXITCODE)" }
Remove-Item $zip -Force

"{0}  ({1:N1} MB)" -f $exe, ((Get-Item $exe).Length / 1MB)
