# SincronizzaFoto - copy photos, videos and files from an Android phone to your PC (USB, no install).
# Start it with Start.bat (double click). Everything lives in this folder: copy the folder to move it.
# License: MIT. See README.md and the guides in docs\.

$script:AppRoot = $PSScriptRoot

try {
    Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase

    foreach ($m in 'i18n', 'core', 'legacy-excel', 'wpf', 'async', 'shellstream', 'worker', 'ui-rule', 'ui-phone', 'ui-quick', 'ui-reorg', 'ui-help', 'ui-main') {
        . (Join-Path $PSScriptRoot "src\$m.ps1")
    }
    Start-App
}
catch {
    # the launcher hides the console, so show unexpected errors in a window and keep a log file
    $msg = "$($_.Exception.Message)`r`n`r`n$($_.ScriptStackTrace)"
    try { Set-Content -LiteralPath (Join-Path $PSScriptRoot "error.log") -Value ("{0}`r`n{1}" -f (Get-Date), $msg) -Encoding UTF8 } catch {}
    [void][System.Windows.MessageBox]::Show($msg, "SincronizzaFoto - error", "OK", "Error")
    exit 1
}
