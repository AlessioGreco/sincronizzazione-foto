# async.ps1 - run a short job in a background STA runspace and get the result back on the UI thread.
# Used by the phone folder browser (listing a phone folder can take a while and must not freeze the window).

$script:AsyncJobs  = New-Object System.Collections.ArrayList
$script:AsyncTimer = New-Object System.Windows.Threading.DispatcherTimer
$script:AsyncTimer.Interval = [TimeSpan]::FromMilliseconds(150)
$script:AsyncTimer.Add_Tick({
    foreach ($j in @($script:AsyncJobs)) {
        if ($j.Handle.IsCompleted) {
            [void]$script:AsyncJobs.Remove($j)
            $res = $null; $err = $null
            try { $res = @($j.Ps.EndInvoke($j.Handle)) } catch { $err = $_.Exception.Message }
            try { $j.Ps.Dispose(); $j.Rs.Close(); $j.Rs.Dispose() } catch {}
            try { & $j.OnDone $res $err $j.Context } catch {}
        }
    }
    if ($script:AsyncJobs.Count -eq 0) { $script:AsyncTimer.Stop() }
})

# $onDone is called on the UI thread as: & $onDone $resultArray $errorText $context
function Start-AsyncJob([scriptblock]$script, [object[]]$arguments, [scriptblock]$onDone, $context = $null) {
    $rs = [runspacefactory]::CreateRunspace()
    $rs.ApartmentState = "STA"; $rs.ThreadOptions = "ReuseThread"; $rs.Open()
    $ps = [powershell]::Create(); $ps.Runspace = $rs
    [void]$ps.AddScript($script.ToString())
    foreach ($a in $arguments) { [void]$ps.AddArgument($a) }
    $job = @{ Ps = $ps; Rs = $rs; Handle = $ps.BeginInvoke(); OnDone = $onDone; Context = $context }
    [void]$script:AsyncJobs.Add($job)
    $script:AsyncTimer.Start()
    return $job
}

# Lists the sub-folders of a phone folder. $storageName = "" lists the phone's storages instead.
$script:ListPhoneFoldersScript = {
    param($phoneName, $storageName, $relPath)
    try {
        $shell = New-Object -ComObject Shell.Application
        $fake = $env:SINCRONIZZAFOTO_FAKE_PHONE   # developer test mode: a PC folder acts as the phone
        $fakeName = if ($env:SINCRONIZZAFOTO_FAKE_PHONE_NAME) { $env:SINCRONIZZAFOTO_FAKE_PHONE_NAME } else { "Fake phone (test)" }
        if ($fake -and $phoneName -eq $fakeName) { $phone = $shell.NameSpace((Split-Path $fake -Parent)).ParseName((Split-Path $fake -Leaf)) }
        else { $phone = $shell.NameSpace(17).Items() | Where-Object { -not $_.IsFileSystem -and $_.Name -eq $phoneName } | Select-Object -First 1 }
        if (-not $phone) { return @{ Ok = $false; Error = "nophone" } }
        $storages = @($phone.GetFolder.Items())
        if (-not $storageName) { return @{ Ok = $true; Folders = @($storages | ForEach-Object { $_.Name }) } }
        $cur = $storages | Where-Object { $_.Name -eq $storageName } | Select-Object -First 1
        if ($relPath) {
            foreach ($part in ($relPath -split '\\')) {
                $next = $null
                foreach ($i in $cur.GetFolder.Items()) { if ($i.IsFolder -and $i.Name -eq $part) { $next = $i; break } }
                if (-not $next) { return @{ Ok = $false; Error = "notfound" } }
                $cur = $next
            }
        }
        $names = New-Object System.Collections.ArrayList
        foreach ($i in $cur.GetFolder.Items()) { if ($i.IsFolder) { [void]$names.Add($i.Name) } }
        return @{ Ok = $true; Folders = @($names | Sort-Object) }
    } catch { return @{ Ok = $false; Error = $_.Exception.Message } }
}
