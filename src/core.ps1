# core.ps1 - constants, data folder, config (config.json), history, presets, helpers

$script:AppName    = "SincronizzaFoto"
$script:AppVersion = "1.0.0"

# File extensions behind each "type" checkbox
$script:TypeExt = [ordered]@{
    photos    = "jpg jpeg png heic heif webp gif bmp dng"
    videos    = "mp4 mov 3gp mkv avi webm m4v"
    audio     = "mp3 m4a wav ogg aac flac opus amr"
    documents = "pdf doc docx xls xlsx ppt pptx txt odt ods csv rtf"
}
$script:Organizations = @("flat", "year", "yearMonth", "mirror")

# ---------- data folder (portable: next to the program; falls back to %APPDATA% if read-only) ----------
function Test-Writable($dir) {
    try {
        $f = Join-Path $dir (".w_" + [guid]::NewGuid().ToString("N"))
        [IO.File]::WriteAllText($f, "x"); Remove-Item -LiteralPath $f -Force
        return $true
    } catch { return $false }
}

function Initialize-DataDir {
    # the single-file SincronizzaFoto.exe unpacks the app to a temporary folder and points here
    if ($env:SINCRONIZZAFOTO_DATA) {
        $script:DataDir = $env:SINCRONIZZAFOTO_DATA
        New-Item -ItemType Directory -Force $script:DataDir | Out-Null
    }
    elseif (Test-Writable $script:AppRoot) { $script:DataDir = $script:AppRoot }
    else {
        $script:DataDir = Join-Path $env:APPDATA $script:AppName
        New-Item -ItemType Directory -Force $script:DataDir | Out-Null
    }
    $script:ConfigPath  = Join-Path $script:DataDir "config.json"
    $script:HistoryPath = Join-Path $script:DataDir "history.json"
}

# ---------- paths ----------
# Store paths under the user's profile as %USERPROFILE%\... so a config can be shared with a friend
function Compress-Path($p) {
    if (-not $p) { return $p }
    $up = $env:USERPROFILE
    if ($up -and $p.StartsWith($up, [StringComparison]::OrdinalIgnoreCase) -and ($p.Length -eq $up.Length -or $p[$up.Length] -eq '\')) {
        return '%USERPROFILE%' + $p.Substring($up.Length)
    }
    return $p
}
function Expand-Path($p) { if (-not $p) { return $p }; return [Environment]::ExpandEnvironmentVariables($p) }

# ---------- rules ----------
function New-Rule($name = "", $phone = "", $dest = "") {
    [pscustomobject]@{
        id                = [guid]::NewGuid().ToString("N").Substring(0, 12)
        name              = $name
        enabled           = $true
        phoneFolder       = $phone
        destFolder        = $dest
        fileTypes         = @()          # photos / videos / audio / documents  (empty + no extensions = everything)
        extensions        = @()          # extra extensions, e.g. "pdf", "zip"
        includeSubfolders = $false
        excludedFolders   = @()          # subfolders to skip: a name ("Thumbnails", any depth) or a path ("Sent\Private") relative to the phone folder
        organization     = "flat"       # flat / year / yearMonth / mirror
    }
}

# Builds a complete rule from a (possibly partial) object, e.g. one loaded from JSON
function Normalize-Rule($r) {
    $n = New-Rule
    if ($r.id)                    { $n.id = [string]$r.id }
    if ($null -ne $r.name)        { $n.name = [string]$r.name }
    if ($null -ne $r.enabled)     { $n.enabled = [bool]$r.enabled }
    if ($null -ne $r.phoneFolder) { $n.phoneFolder = [string]$r.phoneFolder }
    if ($null -ne $r.destFolder)  { $n.destFolder = [string]$r.destFolder }
    $n.fileTypes  = @(@($r.fileTypes)  | Where-Object { $_ } | ForEach-Object { [string]$_ })
    $n.extensions = @(@($r.extensions) | Where-Object { $_ } | ForEach-Object { [string]$_ })
    if ($null -ne $r.includeSubfolders) { $n.includeSubfolders = [bool]$r.includeSubfolders }
    $n.excludedFolders = @(@($r.excludedFolders) | Where-Object { $_ } | ForEach-Object { ([string]$_).Trim().Trim('\', '/') -replace '/', '\' } | Where-Object { $_ })
    if ($script:Organizations -contains [string]$r.organization) { $n.organization = [string]$r.organization }
    return $n
}

# Rule -> plain object for the background worker (expanded paths, list of extensions)
function ConvertTo-WorkerRule($r) {
    $exts = @()
    foreach ($t in @($r.fileTypes)) { if ($script:TypeExt.Contains($t)) { $exts += ($script:TypeExt[$t] -split ' ') } }
    foreach ($e in @($r.extensions)) { $x = ([string]$e).Trim().TrimStart('.').ToLower(); if ($x) { $exts += $x } }
    [pscustomobject]@{
        Id      = $r.id
        Name    = $r.name
        Phone   = (([string]$r.phoneFolder).Trim().Trim('\', '/') -replace '/', '\')
        Dest    = (Expand-Path $r.destFolder)
        Exts    = @($exts | Select-Object -Unique)
        Recurse = [bool]$r.includeSubfolders
        Excluded = @(@($r.excludedFolders) | Where-Object { $_ } | ForEach-Object { ([string]$_).Trim().Trim('\', '/') -replace '/', '\' } | Where-Object { $_ })
        Org     = [string]$r.organization
    }
}

# Example path shown in the editor for each organization option
function Get-OrgExample($dest, $org) {
    $d = if ($dest) { (Expand-Path $dest).TrimEnd('\') } else { "D:\Phone\Camera" }
    $f = "IMG_20261117_105300.jpg"
    switch ($org) {
        "year"      { return "$d\2026\$f" }
        "yearMonth" { return "$d\2026-11\$f" }
        "mirror"    { return "$d\Trips\$f" }
        default     { return "$d\$f" }
    }
}

# Phone folders offered by the quick setup and the editor's drop-down
function Get-Presets {
    $wa = 'Android\media\com.whatsapp\WhatsApp\Media'
    @(
        [pscustomobject]@{ Key = 'camera';          Phone = 'DCIM\Camera';           Dest = 'Camera';             Sub = $false; Default = $true  },
        [pscustomobject]@{ Key = 'screenshots';     Phone = 'Pictures\Screenshots';  Dest = 'Screenshots';        Sub = $false; Default = $true  },
        [pscustomobject]@{ Key = 'whatsapp_images'; Phone = "$wa\WhatsApp Images";   Dest = 'WhatsApp Images';    Sub = $true;  Default = $false },
        [pscustomobject]@{ Key = 'whatsapp_video';  Phone = "$wa\WhatsApp Video";    Dest = 'WhatsApp Video';     Sub = $true;  Default = $false },
        [pscustomobject]@{ Key = 'whatsapp_docs';  Phone = "$wa\WhatsApp Documents"; Dest = 'WhatsApp Documents'; Sub = $true;  Default = $false },
        [pscustomobject]@{ Key = 'downloads';       Phone = 'Download';              Dest = 'Download';           Sub = $true;  Default = $false },
        [pscustomobject]@{ Key = 'documents';       Phone = 'Documents';             Dest = 'Documents';          Sub = $true;  Default = $false },
        [pscustomobject]@{ Key = 'movies';          Phone = 'Movies';                Dest = 'Movies';             Sub = $false; Default = $false },
        [pscustomobject]@{ Key = 'music';           Phone = 'Music';                 Dest = 'Music';              Sub = $true;  Default = $false },
        [pscustomobject]@{ Key = 'recordings';      Phone = 'Recordings';            Dest = 'Recordings';         Sub = $false; Default = $false }
    )
}

# ---------- config.json ----------
$script:ConfigError = $null

function Load-Config {
    $cfg = [pscustomobject]@{ version = 1; language = "auto"; theme = "auto"; rules = @() }
    if (Test-Path -LiteralPath $script:ConfigPath) {
        try {
            $j = Get-Content -LiteralPath $script:ConfigPath -Raw -Encoding UTF8 | ConvertFrom-Json
            if ($j.language) { $cfg.language = [string]$j.language }
            if ($j.theme -in "auto", "light", "dark") { $cfg.theme = [string]$j.theme }
            $cfg.rules = @(@($j.rules) | Where-Object { $_ } | ForEach-Object { Normalize-Rule $_ })
        } catch { $script:ConfigError = $_.Exception.Message }
    }
    return $cfg
}

function Save-Config($cfg) {
    try {
        $json = ConvertTo-Json -InputObject $cfg -Depth 6
        [IO.File]::WriteAllText($script:ConfigPath, $json, (New-Object Text.UTF8Encoding $false))
        return $true
    } catch { return $false }
}

# Share rules with a friend: only the rules (no history, no language)
function Export-Rules($path, $rules) {
    $obj = [pscustomobject]@{ app = $script:AppName; version = 1; rules = @($rules) }
    [IO.File]::WriteAllText($path, (ConvertTo-Json -InputObject $obj -Depth 6), (New-Object Text.UTF8Encoding $false))
}

# Returns the rules found in a shared file, with fresh ids so they never clash with existing ones
function Import-Rules($path) {
    $j = Get-Content -LiteralPath $path -Raw -Encoding UTF8 | ConvertFrom-Json
    $out = @()
    foreach ($r in @($j.rules)) {
        if (-not $r) { continue }
        $n = Normalize-Rule $r
        $n.id = [guid]::NewGuid().ToString("N").Substring(0, 12)
        if ($n.phoneFolder -and $n.destFolder) { $out += $n }
    }
    return $out
}

# ---------- history (last sync per rule) ----------
function Load-History {
    $h = @{}
    try {
        if (Test-Path -LiteralPath $script:HistoryPath) {
            $j = Get-Content -LiteralPath $script:HistoryPath -Raw -Encoding UTF8 | ConvertFrom-Json
            foreach ($p in $j.PSObject.Properties) { $h[$p.Name] = $p.Value }
        }
    } catch {}
    return $h
}
function Save-History($h) {
    try { [IO.File]::WriteAllText($script:HistoryPath, (ConvertTo-Json -InputObject $h -Depth 4), (New-Object Text.UTF8Encoding $false)) } catch {}
}

function Format-LastSync($id) {
    $e = $script:History[$id]
    if (-not $e -or -not $e.Last) { return (T 'last.never') }
    try { $d = [datetime]::Parse([string]$e.Last, [Globalization.CultureInfo]::InvariantCulture) } catch { return (T 'last.never') }
    $ts = (Get-Date) - $d
    if     ($ts.TotalMinutes -lt 1)  { $ago = T 'last.now' }
    elseif ($ts.TotalMinutes -lt 60) { $ago = T 'last.min'   ([int]$ts.TotalMinutes) }
    elseif ($ts.TotalHours   -lt 24) { $ago = T 'last.hours' ([int]$ts.TotalHours) }
    elseif ($ts.TotalDays    -lt 2)  { $ago = T 'last.yesterday' }
    else                             { $ago = T 'last.days'  ([int]$ts.TotalDays) }
    $copied = [int]$e.Copied
    $new = if ($copied -eq 1) { T 'last.new1' } else { T 'last.newn' $copied }
    $err = if ([int]$e.Failed -gt 0) { T 'last.err' ([int]$e.Failed) } else { "" }
    return (T 'last.fmt' $ago ($d.ToString("dd/MM/yyyy HH:mm")) $new $err)
}

# ---------- tidy up files that were already copied (after changing a rule's structure) ----------
# Safe by design: nothing is deleted or overwritten; only files in the folder itself and in year / month
# folders are considered (any other subfolder may be the user's own); a file whose new place is taken is left.

function Get-NameDate([string]$name) {
    if ($name -match '(20\d{2})(0[1-9]|1[0-2])(0[1-9]|[12]\d|3[01])') {
        try { return [datetime]::new([int]$Matches[1], [int]$Matches[2], [int]$Matches[3]) } catch {}
    }
    return $null
}

# date of a file already on the PC: from its name, else its modified date
function Get-LocalFileDate($fi) {
    $d = Get-NameDate $fi.Name
    if ($d) { return $d }
    if ($fi.LastWriteTime.Year -ge 1990) { return $fi.LastWriteTime }
    return $null
}

function Test-DateFolderName([string]$n) { ($n -match '^\d{4}$') -or ($n -match '^\d{4}-\d{2}$') -or ($n -eq (T 'w.nodate')) }

function Get-OrgTargetDir([string]$destRoot, [string]$org, $fi) {
    switch ($org) {
        "year"      { $d = Get-LocalFileDate $fi; return (Join-Path $destRoot $(if ($d) { $d.ToString("yyyy") } else { T 'w.nodate' })) }
        "yearMonth" { $d = Get-LocalFileDate $fi; return (Join-Path $destRoot $(if ($d) { $d.ToString("yyyy-MM") } else { T 'w.nodate' })) }
        default     { return $destRoot }
    }
}

# Builds the list of moves for a rule. $sourceRoot = where the files are now (the old destination);
# empty = the rule's own destination. Returns @{ Unsupported; Items; Move; InPlace; Conflict; Source; Dest }
function New-ReorganizePlan($rule, [string]$sourceRoot = "") {
    $dest = (Expand-Path $rule.destFolder).TrimEnd('\')
    $src = if ($sourceRoot) { (Expand-Path $sourceRoot).TrimEnd('\') } else { $dest }
    $plan = @{ Unsupported = $false; Items = (New-Object System.Collections.ArrayList); Move = 0; InPlace = 0; Conflict = 0; Source = $src; Dest = $dest }
    if ($rule.organization -eq "mirror") { $plan.Unsupported = $true; return $plan }
    if (-not (Test-Path -LiteralPath $src)) { return $plan }

    $files = New-Object System.Collections.ArrayList
    foreach ($f in @(Get-ChildItem -LiteralPath $src -File -ErrorAction SilentlyContinue)) { [void]$files.Add($f) }
    foreach ($d in @(Get-ChildItem -LiteralPath $src -Directory -ErrorAction SilentlyContinue | Where-Object { Test-DateFolderName $_.Name })) {
        foreach ($f in @(Get-ChildItem -LiteralPath $d.FullName -File -ErrorAction SilentlyContinue)) { [void]$files.Add($f) }
    }
    $taken = @{}
    foreach ($f in $files) {
        $targetDir = Get-OrgTargetDir $dest $rule.organization $f
        $target = Join-Path $targetDir $f.Name
        if ($target -ieq $f.FullName) { $plan.InPlace++; continue }
        if ((Test-Path -LiteralPath $target) -or $taken.ContainsKey($target.ToLower())) { $plan.Conflict++; continue }
        $taken[$target.ToLower()] = $true
        [void]$plan.Items.Add([pscustomobject]@{ From = $f.FullName; To = $target })
        $plan.Move++
    }
    return $plan
}

# Moves one item of the plan. Returns $true on success.
function Move-PlanItem($item) {
    try {
        $dir = Split-Path $item.To -Parent
        if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Force $dir | Out-Null }
        if (Test-Path -LiteralPath $item.To) { return $false }       # never overwrite
        Move-Item -LiteralPath $item.From -Destination $item.To -ErrorAction Stop
        return $true
    } catch { return $false }
}

# Removes year / month folders left empty by the move (only those)
function Remove-EmptyDateFolders([string]$root) {
    if (-not (Test-Path -LiteralPath $root)) { return }
    foreach ($d in @(Get-ChildItem -LiteralPath $root -Directory -ErrorAction SilentlyContinue | Where-Object { Test-DateFolderName $_.Name })) {
        if (-not (Get-ChildItem -LiteralPath $d.FullName -Force -ErrorAction SilentlyContinue | Select-Object -First 1)) { Remove-Item -LiteralPath $d.FullName -Force -ErrorAction SilentlyContinue }
    }
}
