# legacy-excel.ps1 - one-time import of the old Sincronizza.xlsx rules into config.json.
# Reads the .xlsx directly (zip + xml): Excel is not required.

Add-Type -AssemblyName System.IO.Compression

function Read-LegacyExcelRows($path) {
    $fs  = [IO.File]::Open($path, 'Open', 'Read', 'ReadWrite')   # works even if Excel has it open
    $zip = New-Object IO.Compression.ZipArchive($fs, [IO.Compression.ZipArchiveMode]::Read)
    try {
        function Read-Xml($name) {
            $e = $zip.GetEntry($name); if (-not $e) { return $null }
            $sr = New-Object IO.StreamReader($e.Open(), [Text.Encoding]::UTF8)
            try { $x = New-Object Xml.XmlDocument; $x.LoadXml($sr.ReadToEnd()); return $x } finally { $sr.Dispose() }
        }
        $shared = @()
        $ss = Read-Xml "xl/sharedStrings.xml"
        if ($ss) {
            foreach ($si in $ss.SelectNodes("//*[local-name()='si']")) {
                $shared += (($si.SelectNodes(".//*[local-name()='t']") | ForEach-Object { $_.InnerText }) -join "")
            }
        }
        $wb = Read-Xml "xl/workbook.xml"
        $sheets = @($wb.SelectNodes("//*[local-name()='sheet']"))
        $sheet = $sheets | Where-Object { $_.GetAttribute("name") -eq "Regole" } | Select-Object -First 1
        if (-not $sheet) { $sheet = $sheets[0] }
        $rid = $sheet.GetAttribute("id", "http://schemas.openxmlformats.org/officeDocument/2006/relationships")
        $rels = Read-Xml "xl/_rels/workbook.xml.rels"
        $target = ($rels.SelectNodes("//*[local-name()='Relationship']") | Where-Object { $_.GetAttribute("Id") -eq $rid }).GetAttribute("Target")
        $target = $target.TrimStart("/"); if ($target -notlike "xl/*") { $target = "xl/$target" }
        $sx = Read-Xml $target

        $table = @()
        foreach ($row in $sx.SelectNodes("//*[local-name()='row']")) {
            $h = @{}
            foreach ($c in $row.SelectNodes("*[local-name()='c']")) {
                $col = ($c.GetAttribute("r") -replace '\d', '')
                $t = $c.GetAttribute("t"); $val = ""
                if ($t -eq "s") { $v = $c.SelectSingleNode("*[local-name()='v']"); if ($v) { $val = $shared[[int]$v.InnerText] } }
                elseif ($t -eq "inlineStr") { $val = (($c.SelectNodes(".//*[local-name()='t']") | ForEach-Object { $_.InnerText }) -join "") }
                else { $v = $c.SelectSingleNode("*[local-name()='v']"); if ($v) { $val = $v.InnerText } }
                $h[$col] = "$val".Trim()
            }
            $table += ,$h
        }
    } finally { $zip.Dispose(); $fs.Dispose() }
    return $table
}

# Returns new-style rules. Organization is set to "flat" (everything in one folder, like on the phone).
function Import-LegacyExcel($path) {
    $table = Read-LegacyExcelRows $path
    if ($table.Count -lt 2) { return @() }
    $map = @{}
    foreach ($k in $table[0].Keys) { $map[$table[0][$k].ToLower()] = $k }
    foreach ($need in "nome", "cartella telefono", "cartella pc") { if (-not $map.ContainsKey($need)) { throw "Missing column '$need'" } }
    function Cell($r, $name) { if ($map.ContainsKey($name)) { $v = $r[$map[$name]]; if ($v) { return $v } }; return "" }
    $typeMap = @{ foto = "photos"; video = "videos"; audio = "audio"; documenti = "documents" }

    $rules = @()
    for ($i = 1; $i -lt $table.Count; $i++) {
        $r = $table[$i]
        $ph = Cell $r "cartella telefono"; $pc = Cell $r "cartella pc"
        if (-not $ph -or -not $pc) { continue }
        $name = Cell $r "nome"; if (-not $name) { $name = $ph }
        $rule = New-Rule $name (($ph.Trim('\', '/')) -replace '/', '\') (Compress-Path $pc)
        $rule.enabled = ((Cell $r "attiva") -match '^(s|si|sì|y|yes|1|true|x)$')
        $tp = (Cell $r "tipo file").ToLower()
        if ($typeMap.ContainsKey($tp)) { $rule.fileTypes = @($typeMap[$tp]) }
        $custom = Cell $r "estensioni"
        if ($custom) { $rule.extensions = @($custom -split '[,;\s]+' | Where-Object { $_ } | ForEach-Object { $_.TrimStart('.').ToLower() }) }
        $rule.includeSubfolders = ((Cell $r "sottocartelle") -match '^(s|si|sì|y|yes|1|true|x)$')
        $rule.organization = "flat"
        $rules += $rule
    }
    return $rules
}

# Carry over "last sync" info saved by the old version (%APPDATA%\SincronizzaFoto\history.json)
function Import-LegacyHistory($rules) {
    $old = Join-Path $env:APPDATA "SincronizzaFoto\history.json"
    if (-not (Test-Path -LiteralPath $old)) { return }
    try {
        $j = Get-Content -LiteralPath $old -Raw -Encoding UTF8 | ConvertFrom-Json
        foreach ($r in $rules) {
            $oldKey = "{0}|{1}|{2}" -f $r.name, $r.phoneFolder, (Expand-Path $r.destFolder)
            $prop = $j.PSObject.Properties | Where-Object { $_.Name -eq $oldKey } | Select-Object -First 1
            if ($prop) { $script:History[$r.id] = $prop.Value }
        }
        Save-History $script:History
    } catch {}
}
