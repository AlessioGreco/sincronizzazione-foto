# check.ps1 - developer checks: PowerShell syntax, translation keys, placeholders.
# Run:  powershell -ExecutionPolicy Bypass -File tools\check.ps1
$root = Split-Path -Parent $PSScriptRoot
$fail = 0

Write-Host "== Syntax ==" -ForegroundColor Cyan
$files = @(Get-ChildItem $root -Recurse -Include *.ps1 | Where-Object { $_.FullName -notmatch '\\\.git\\' })
foreach ($f in $files) {
    $errs = $null; $tok = $null
    [void][Management.Automation.Language.Parser]::ParseFile($f.FullName, [ref]$tok, [ref]$errs)
    if ($errs) { $fail++; $errs | ForEach-Object { Write-Host ("  {0}:{1}  {2}" -f $f.Name, $_.Extent.StartLineNumber, $_.Message) -ForegroundColor Red } }
    else { Write-Host ("  ok  " + $f.FullName.Substring($root.Length + 1)) }
    # non-ASCII text needs a BOM for Windows PowerShell 5.1
    $bytes = [IO.File]::ReadAllBytes($f.FullName)
    $hasBom = ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF)
    if (-not $hasBom -and ($bytes | Where-Object { $_ -gt 127 } | Select-Object -First 1)) {
        $fail++; Write-Host ("  {0}: has non-ASCII characters but no UTF-8 BOM" -f $f.Name) -ForegroundColor Red
    }
}

Write-Host "== XAML ==" -ForegroundColor Cyan
foreach ($x in Get-ChildItem "$root\ui\*.xaml") {
    try { $null = [xml](Get-Content $x.FullName -Raw -Encoding UTF8); Write-Host ("  ok  ui\" + $x.Name) }
    catch { $fail++; Write-Host ("  ui\{0}: {1}" -f $x.Name, $_.Exception.Message) -ForegroundColor Red }
}

Write-Host "== Translations ==" -ForegroundColor Cyan
$langs = @{}
foreach ($f in Get-ChildItem "$root\lang\*.json") {
    $h = @{}; $j = Get-Content $f.FullName -Raw -Encoding UTF8 | ConvertFrom-Json
    foreach ($p in $j.PSObject.Properties) { $h[$p.Name] = [string]$p.Value }
    $langs[$f.BaseName] = $h
}
$en = $langs["en"]
foreach ($code in $langs.Keys) {
    if ($code -eq "en") { continue }
    $h = $langs[$code]
    foreach ($k in $en.Keys) { if (-not $h.ContainsKey($k)) { $fail++; Write-Host "  [$code] missing key: $k" -ForegroundColor Red } }
    foreach ($k in $h.Keys)  { if (-not $en.ContainsKey($k)) { $fail++; Write-Host "  [$code] extra key (not in en): $k" -ForegroundColor Red } }
    foreach ($k in $en.Keys) {
        if (-not $h.ContainsKey($k)) { continue }
        $a = ([regex]::Matches($en[$k], '\{(\d+)\}') | ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique) -join ","
        $b = ([regex]::Matches($h[$k], '\{(\d+)\}') | ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique) -join ","
        if ($a -ne $b) { $fail++; Write-Host "  [$code] placeholders differ for '$k': en={$a} $code={$b}" -ForegroundColor Red }
    }
    Write-Host ("  {0}: {1} keys" -f $code, $h.Count)
}

# keys used in code must exist
$used = New-Object System.Collections.Generic.SortedSet[string]
foreach ($f in Get-ChildItem "$root\src\*.ps1") {
    $t = Get-Content $f.FullName -Raw -Encoding UTF8
    foreach ($m in [regex]::Matches($t, "\bT\s+['""]([a-z0-9_.]+)['""]")) { [void]$used.Add($m.Groups[1].Value) }
    foreach ($m in [regex]::Matches($t, "Bind-Text\s+\S+\s+['""]([a-z0-9_.]+)['""]")) { [void]$used.Add($m.Groups[1].Value) }
}
foreach ($o in 'flat', 'year', 'yearMonth', 'mirror') { [void]$used.Add("org.$o.title"); [void]$used.Add("org.$o.desc"); [void]$used.Add("org.$o.short") }
foreach ($m in 'auto', 'light', 'dark') { [void]$used.Add("theme.$m") }
foreach ($k in $used) { if ($k -ne "key" -and -not $en.ContainsKey($k)) { $fail++; Write-Host "  key used in code but not in en.json: $k" -ForegroundColor Red } }
foreach ($k in $en.Keys) {
    if (-not $used.Contains($k) -and $k -notmatch '^(preset|type)\.') { Write-Host "  (unused key: $k)" -ForegroundColor DarkYellow }
}

if ($fail -eq 0) { Write-Host "`nAll checks passed." -ForegroundColor Green } else { Write-Host "`n$fail problem(s)." -ForegroundColor Red }
exit $fail
