# worker.ps1 - the copy job. It runs in a separate STA runspace so the window never freezes,
# even while Windows is slowly listing a huge phone folder. It talks to the UI through a
# synchronized hashtable ($sync): phase/status text, counters, a log queue and a cancel flag.

$script:WorkerScript = {
    param($sync, $sel, $phoneName, $showSkipped, $strings)

    function T([string]$key) {
        $s = $strings[$key]
        if ($null -eq $s) { return "[$key]" }
        if ($args.Count -gt 0) { return ($s -f $args) }
        return $s
    }
    function Log($m) { $sync.Log.Enqueue(("[{0:HH:mm:ss}] {1}" -f (Get-Date), $m)) }
    function Status($phase, $detail) { $sync.Phase = $phase; $sync.Status = $detail }
    function Format-Size($b) {
        if ($b -ge 1GB) { return ("{0:N1} GB" -f ($b / 1GB)) }
        if ($b -ge 1MB) { return ("{0:N1} MB" -f ($b / 1MB)) }
        return ("{0:N0} KB" -f ($b / 1KB))
    }
    function Get-SubItem($folderItem, $name) {
        foreach ($i in $folderItem.GetFolder.Items()) { if ($i.Name -eq $name) { return $i } }
        return $null
    }
    # Real file name. NB: .Path on MTP phones ends with an internal {GUID}, not the name; and .Name may hide the extension.
    function Get-RealName($item) {
        $n = [string]$item.Name
        try {
            $fn = [string]$item.ExtendedProperty("System.FileName")
            if ($fn -and $fn -notmatch '^\{[0-9A-Fa-f-]{36}\}$') { return $fn }
        } catch {}
        try {
            $ext = [string]$item.ExtendedProperty("System.FileExtension")
            if ($ext -and -not $n.EndsWith($ext, [StringComparison]::OrdinalIgnoreCase)) { return $n + $ext }
        } catch {}
        return $n
    }
    # .Size is 0 on MTP phones, System.Size has the real value
    function Get-ItemSize($item) {
        try { $v = $item.ExtendedProperty("System.Size"); if ($v -and [int64]$v -gt 0) { return [int64]$v } } catch {}
        try { if ([int64]$item.Size -gt 0) { return [int64]$item.Size } } catch {}
        return [int64]0
    }
    # Is there already a copy in $dir? Same name + same size, or "name (1).ext", "name (2).ext"... with that size.
    # (unknown size = the name alone is enough)
    function Test-HasCopy($dir, $name, $size) {
        $ext = [IO.Path]::GetExtension($name); $base = [IO.Path]::GetFileNameWithoutExtension($name)
        for ($i = 0; $i -le 30; $i++) {
            $n = if ($i -eq 0) { $name } else { "$base ($i)$ext" }
            $p = Join-Path $dir $n
            if (-not (Test-Path -LiteralPath $p)) { return $false }
            if ($size -le 0 -or (Get-Item -LiteralPath $p).Length -eq $size) { return $true }
        }
        return $false
    }
    # First free name in $dir: "name.ext", else "name (1).ext", "name (2).ext"... (never overwrite a different file)
    function Get-FreeName($dir, $name) {
        $ext = [IO.Path]::GetExtension($name); $base = [IO.Path]::GetFileNameWithoutExtension($name)
        $n = $name; $i = 0
        while (Test-Path -LiteralPath (Join-Path $dir $n)) { $i++; $n = "$base ($i)$ext" }
        return $n
    }
    # Date of a file: from its name (IMG_20261117_..., IMG-20261117-WA..., PXL_...), else the modification date
    function Get-FileDate($item, $name) {
        if ($name -match '(20\d{2})(0[1-9]|1[0-2])(0[1-9]|[12]\d|3[01])') {
            try { return [datetime]::new([int]$Matches[1], [int]$Matches[2], [int]$Matches[3]) } catch {}
        }
        try { $v = $item.ExtendedProperty("System.DateModified"); if ($v -is [datetime] -and $v.Year -ge 1990) { return $v } } catch {}
        try { $d = $item.ModifyDate; if ($d.Year -ge 1990) { return $d } } catch {}
        return $null
    }

    function Collect-Files($folderItem, $rel, $recurse, $list, $rule) {
        $where = if ($rel) { "$($rule.Phone)\$rel" } else { $rule.Phone }
        Status (T 'w.phase1') (T 'w.opening' $rule.Name $where)
        # Walk the listing one element at a time (not all at once): the counter climbs immediately
        # even on huge folders, so it is always clear that work is in progress.
        $i = 0
        foreach ($f in $folderItem.GetFolder.Items()) {
            if ($sync.Cancel) { return }
            $i++
            if ($i % 10 -eq 0) { Status (T 'w.phase1') (T 'w.reading' $rule.Name $where $i $list.Count) }
            $real = Get-RealName $f
            # Windows treats .zip/.cab as "folders": they are files for us, not subfolders to walk into
            $isDir = $f.IsFolder -and ([IO.Path]::GetExtension($real).ToLower() -notin ".zip", ".cab")
            if ($isDir) {
                if ($recurse) {
                    $subRel = if ($rel) { Join-Path $rel $f.Name } else { $f.Name }
                    # excluded by name (any depth) or by path relative to the rule's phone folder
                    $skip = $false
                    foreach ($x in $rule.Excluded) {
                        if ($x -like '*\*') { if ($subRel -ieq $x) { $skip = $true; break } }
                        elseif ($f.Name -ieq $x) { $skip = $true; break }
                    }
                    if ($skip) { Log (T 'w.excluded' $rule.Name $subRel); continue }
                    Collect-Files $f $subRel $true $list $rule
                }
                continue
            }
            if ($rule.Exts.Count -gt 0) {
                $ext = [IO.Path]::GetExtension($real).TrimStart('.').ToLower()
                if ($rule.Exts -notcontains $ext) { continue }
            }
            [void]$list.Add([pscustomobject]@{ Rule = $rule; Item = $f; Name = $real; Rel = $rel })
        }
    }

    # Developer test mode: SINCRONIZZAFOTO_FAKE_PHONE=<folder> makes a PC folder act as the phone (see CONTRIBUTING.md)
    function Get-PhoneItem($shell, $name) {
        $fake = $env:SINCRONIZZAFOTO_FAKE_PHONE
        $fakeName = if ($env:SINCRONIZZAFOTO_FAKE_PHONE_NAME) { $env:SINCRONIZZAFOTO_FAKE_PHONE_NAME } else { "Fake phone (test)" }
        if ($fake -and $name -eq $fakeName) { return $shell.NameSpace((Split-Path $fake -Parent)).ParseName((Split-Path $fake -Leaf)) }
        return $shell.NameSpace(17).Items() | Where-Object { -not $_.IsFileSystem -and $_.Name -eq $name } | Select-Object -First 1
    }

    try {
        $shell = New-Object -ComObject Shell.Application
        $phone = Get-PhoneItem $shell $phoneName
        if (-not $phone) { Log (T 'w.phone_gone'); $sync.Outcome = "error"; $sync.Error = (T 'w.phone_gone'); return }
        Log (T 'w.starting' $sel.Count $phone.Name)

        # ---- step 1: list the files of every selected rule ----
        $sync.Marquee = $true
        $stats = $sync.Stats
        $todo = New-Object System.Collections.ArrayList
        $ri = 0
        foreach ($rule in $sel) {
            if ($sync.Cancel) { break }
            $ri++
            $stats[$rule.Id] = @{ Found = $false; Total = 0; Done = 0; Copied = 0; Skipped = 0; Failed = 0 }
            Status (T 'w.phase1') (T 'w.rule_of' $ri $sel.Count $rule.Name $rule.Phone)
            $found = $false
            foreach ($storage in $phone.GetFolder.Items()) {
                $cur = $storage
                foreach ($part in ($rule.Phone -split '\\')) {
                    $cur = Get-SubItem $cur $part
                    if (-not $cur) { break }
                }
                if (-not $cur) { continue }
                $found = $true
                $before = $todo.Count
                Collect-Files $cur "" $rule.Recurse $todo $rule
                Log (T 'w.found' $rule.Name ($todo.Count - $before))
            }
            if (-not $found) { Log (T 'w.notfound' $rule.Name $rule.Phone) }
            $stats[$rule.Id].Found = $found
        }
        $sync.Marquee = $false
        if ($sync.Cancel) { Log (T 'w.stopped'); $sync.Outcome = "cancel-read"; return }
        foreach ($x in $todo) { $stats[$x.Rule.Id].Total++ }
        if ($todo.Count -eq 0) { Log (T 'w.nofiles'); $sync.Outcome = "empty"; return }

        # ---- step 2: copy only what is missing ----
        Log (T 'w.total' $todo.Count)
        $sync.Max = $todo.Count
        $copied = 0; $skipped = 0; $failed = 0; $n = 0; $lastRule = $null
        $stage = Join-Path ([IO.Path]::GetTempPath()) "SincronizzaFoto_stage"
        New-Item -ItemType Directory -Force $stage | Out-Null
        $useDirect = $true      # read the bytes ourselves; falls back to Windows' copy if this phone refuses

        foreach ($x in $todo) {
            if ($sync.Cancel) { Log (T 'w.stopped'); break }
            $n++; $sync.Value = $n
            $rule = $x.Rule
            $st = $stats[$rule.Id]; $st.Done++
            if ($rule -ne $lastRule) { Log (T 'w.ruleheader' $rule.Name $rule.Dest); $lastRule = $rule }
            $pct = [int](100 * $n / $todo.Count)
            Status (T 'w.phase2' $n $todo.Count $pct) (T 'w.copy_status' $rule.Name $x.Name $copied $skipped $failed)

            # where does this file go?
            $fd = $null
            if ($rule.Org -eq "year" -or $rule.Org -eq "yearMonth") { $fd = Get-FileDate $x.Item $x.Name }
            switch ($rule.Org) {
                "year"      { $dir = Join-Path $rule.Dest $(if ($fd) { $fd.ToString("yyyy") }    else { T 'w.nodate' }) }
                "yearMonth" { $dir = Join-Path $rule.Dest $(if ($fd) { $fd.ToString("yyyy-MM") } else { T 'w.nodate' }) }
                "mirror"    { $dir = if ($x.Rel) { Join-Path $rule.Dest $x.Rel } else { $rule.Dest } }
                default     { $dir = $rule.Dest }
            }
            $size = Get-ItemSize $x.Item
            $dateOrg = ($rule.Org -eq "year" -or $rule.Org -eq "yearMonth")

            # Already there? Same name + same size = duplicate. With date folders also look in the
            # destination root (files copied there in the past without subfolders).
            $already = (Test-HasCopy $dir $x.Name $size) -or ($dateOrg -and (Test-HasCopy $rule.Dest $x.Name $size))
            if ($already) {
                $skipped++; $st.Skipped++
                if ($showSkipped) { Log (T 'w.exists' $x.Name) }
                continue
            }

            $sizeTxt = if ($size -gt 0) { Format-Size $size } else { T 'w.size_unknown' }
            Log (T 'w.copy_log' $x.Name $sizeTxt)
            New-Item -ItemType Directory -Force $dir | Out-Null

            # Copy into an empty temp folder first: a half-copied file never reaches the destination
            Get-ChildItem -LiteralPath $stage -Force -ErrorAction SilentlyContinue | Remove-Item -Force -Recurse -ErrorAction SilentlyContinue
            $got = $null
            $sync.FileFraction = 0.0

            # 1) direct copy: we read the bytes ourselves (no Windows copy window, real progress, cancel works)
            if ($useDirect) {
                try {
                    $stagePath = Join-Path $stage $x.Name
                    $fmtOf = $strings['w.transfer_of']; $fmtNo = $strings['w.transfer']
                    $rName = [string]$rule.Name; $fName = [string]$x.Name; $fSize = [int64]$size
                    $cbBlock = {
                        param($n)
                        $sz = if ($n -ge 1GB) { "{0:N2} GB" -f ($n / 1GB) } else { "{0:N1} MB" -f ($n / 1MB) }
                        if ($fSize -gt 0) {
                            $tt = if ($fSize -ge 1GB) { "{0:N2} GB" -f ($fSize / 1GB) } else { "{0:N1} MB" -f ($fSize / 1MB) }
                            $sync.FileFraction = [Math]::Min(1.0, [double]$n / [double]$fSize)
                            $sync.Status = $fmtOf -f $rName, $fName, $sz, $tt
                        } else { $sync.Status = $fmtNo -f $rName, $fName, $sz }
                    }.GetNewClosure()
                    $cbCancel = { [bool]$sync.Cancel }.GetNewClosure()
                    [void][SF.ShellStream]::CopyToFile($x.Item.PSObject.BaseObject, $stagePath, [Action[long]]$cbBlock, [Func[bool]]$cbCancel)
                    $got = Get-Item -LiteralPath $stagePath -ErrorAction SilentlyContinue
                    # keep the photo's own date as the file's modified date (a copy would otherwise get "now")
                    try { $dm = $x.Item.ExtendedProperty("System.DateModified"); if ($got -and $dm -is [datetime] -and $dm.Year -ge 1990) { $got.LastWriteTime = $dm } } catch {}
                }
                catch {
                    Get-ChildItem -LiteralPath $stage -Force -ErrorAction SilentlyContinue | Remove-Item -Force -Recurse -ErrorAction SilentlyContinue
                    $got = $null
                    if (-not $sync.Cancel) { $useDirect = $false; Log (T 'w.fallback') }   # this phone: use the Windows copy from now on
                }
            }

            # 2) fallback: Windows' own copy (it may show its progress window for big files)
            if (-not $got -and -not $useDirect -and -not $sync.Cancel) {
                $shell.NameSpace($stage).CopyHere($x.Item, 0x14)   # 0x4 no dialogs + 0x10 "yes to all"
                # CopyHere can be asynchronous: wait for the complete file (max ~10 min)
                $t = 0; $stable = 0; $lastLen = -1
                while ($t -lt 2000) {
                    $got = Get-ChildItem -LiteralPath $stage -File -Force -ErrorAction SilentlyContinue | Select-Object -First 1
                    if ($got) {
                        if ($size -gt 0) { if ($got.Length -ge $size) { break } }
                        else {   # unknown size: finished when it stops growing
                            if ($got.Length -eq $lastLen) { $stable++ } else { $stable = 0; $lastLen = $got.Length }
                            if ($stable -ge 2) { break }
                        }
                        $sync.Status = if ($size -gt 0) { T 'w.transfer_of' $rule.Name $x.Name (Format-Size $got.Length) (Format-Size $size) }
                                       else { T 'w.transfer' $rule.Name $x.Name (Format-Size $got.Length) }
                    }
                    Start-Sleep -Milliseconds 300; $t++
                    if ($sync.Cancel) { break }
                }
            }

            if (-not $got -or ($size -gt 0 -and $got.Length -lt $size)) {
                if ($sync.Cancel) { $st.Done--; continue }   # stopped by the user: neither an error nor "done"
                $failed++; $st.Failed++; Log (T 'w.error_incomplete' $x.Name)
                continue
            }
            # move into the destination with the real name Windows assigned
            $isDup = (Test-HasCopy $dir $got.Name $got.Length) -or ($dateOrg -and (Test-HasCopy $rule.Dest $got.Name $got.Length))
            if ($isDup) {
                $skipped++; $st.Skipped++; Remove-Item -LiteralPath $got.FullName -Force
                if ($showSkipped) { Log (T 'w.exists' $got.Name) }
            } else {
                # never overwrite: a different file with the same name keeps its place, the new one becomes "name (1).ext"
                $freeName = Get-FreeName $dir $got.Name
                if ($freeName -ne $got.Name) { Log (T 'w.renamed' $got.Name $freeName) }
                Move-Item -LiteralPath $got.FullName -Destination (Join-Path $dir $freeName)
                $copied++; $st.Copied++
            }
        }
        $sync.Copied = $copied; $sync.Skipped = $skipped; $sync.Failed = $failed
        $sync.Outcome = if ($sync.Cancel) { "cancel" } else { "ok" }
    }
    catch { Log (T 'w.error' $_.Exception.Message); $sync.Outcome = "error"; $sync.Error = $_.Exception.Message }
    finally { $sync.Done = $true }
}
