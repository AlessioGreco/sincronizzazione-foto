# ui-help.ps1 - in-app user guide (Markdown rendered to HTML) and the About window (WPF)

# Minimal Markdown -> HTML (headings, lists, bold, italic, `code`, links, quotes, code blocks, rules).
# Enough for the guides in docs\; no tables.
function ConvertFrom-MiniMarkdown([string]$md, [bool]$dark = $false) {
    function Fmt($t) {
        $t = [System.Net.WebUtility]::HtmlEncode($t)
        $t = [regex]::Replace($t, '\*\*(.+?)\*\*', '<b>$1</b>')
        $t = [regex]::Replace($t, '(?<![\*\w])\*(?=\S)(.+?)(?<=\S)\*(?![\*\w])', '<i>$1</i>')
        $t = [regex]::Replace($t, '`([^`]+)`', '<code>$1</code>')
        $t = [regex]::Replace($t, '\[([^\]]+)\]\(([^)]+)\)', '<a href="$2">$1</a>')
        return $t
    }
    $out = New-Object System.Text.StringBuilder
    $para = New-Object System.Collections.ArrayList
    $st = @{ List = $null; Code = $false }

    foreach ($line in ($md -split "`r?`n")) {
        if ($line -match '^```') {
            if ($para.Count) { [void]$out.Append("<p>" + (Fmt ($para -join " ")) + "</p>`n"); $para.Clear() }
            if ($st.List) { [void]$out.Append("</$($st.List)>`n"); $st.List = $null }
            if ($st.Code) { [void]$out.Append("</pre>`n"); $st.Code = $false } else { [void]$out.Append("<pre>"); $st.Code = $true }
            continue
        }
        if ($st.Code) { [void]$out.Append([System.Net.WebUtility]::HtmlEncode($line) + "`n"); continue }

        if ($line -match '^\s*$') {
            if ($para.Count) { [void]$out.Append("<p>" + (Fmt ($para -join " ")) + "</p>`n"); $para.Clear() }
            if ($st.List) { [void]$out.Append("</$($st.List)>`n"); $st.List = $null }
            continue
        }
        if ($line -match '^(#{1,3})\s+(.*)$') {
            if ($para.Count) { [void]$out.Append("<p>" + (Fmt ($para -join " ")) + "</p>`n"); $para.Clear() }
            if ($st.List) { [void]$out.Append("</$($st.List)>`n"); $st.List = $null }
            $lv = $Matches[1].Length
            [void]$out.Append("<h$lv>" + (Fmt $Matches[2]) + "</h$lv>`n")
        }
        elseif ($line -match '^---+\s*$') {
            if ($para.Count) { [void]$out.Append("<p>" + (Fmt ($para -join " ")) + "</p>`n"); $para.Clear() }
            if ($st.List) { [void]$out.Append("</$($st.List)>`n"); $st.List = $null }
            [void]$out.Append("<hr>`n")
        }
        elseif ($line -match '^\s*[-*]\s+(.*)$') {
            $item = $Matches[1]
            if ($para.Count) { [void]$out.Append("<p>" + (Fmt ($para -join " ")) + "</p>`n"); $para.Clear() }
            if ($st.List -ne "ul") { if ($st.List) { [void]$out.Append("</$($st.List)>`n") }; [void]$out.Append("<ul>`n"); $st.List = "ul" }
            [void]$out.Append("<li>" + (Fmt $item) + "</li>`n")
        }
        elseif ($line -match '^\s*\d+\.\s+(.*)$') {
            $item = $Matches[1]
            if ($para.Count) { [void]$out.Append("<p>" + (Fmt ($para -join " ")) + "</p>`n"); $para.Clear() }
            if ($st.List -ne "ol") { if ($st.List) { [void]$out.Append("</$($st.List)>`n") }; [void]$out.Append("<ol>`n"); $st.List = "ol" }
            [void]$out.Append("<li>" + (Fmt $item) + "</li>`n")
        }
        elseif ($line -match '^>\s?(.*)$') {
            $q = $Matches[1]
            if ($para.Count) { [void]$out.Append("<p>" + (Fmt ($para -join " ")) + "</p>`n"); $para.Clear() }
            if ($st.List) { [void]$out.Append("</$($st.List)>`n"); $st.List = $null }
            [void]$out.Append("<blockquote>" + (Fmt $q) + "</blockquote>`n")
        }
        else {
            if ($st.List) { [void]$out.Append("</$($st.List)>`n"); $st.List = $null }
            [void]$para.Add($line.Trim())
        }
    }
    if ($para.Count) { [void]$out.Append("<p>" + (Fmt ($para -join " ")) + "</p>`n") }
    if ($st.List) { [void]$out.Append("</$($st.List)>`n") }
    if ($st.Code) { [void]$out.Append("</pre>`n") }

    # colors follow the app theme (same hex values as ui\palette.*.xaml)
    if ($dark) { $bg = "#131416"; $tx = "#ECEAE4"; $mu = "#9AA0A6"; $cd = "#26292D"; $ac = "#FFC233"; $qb = "#3A2F12"; $ln = "#34383D" }
    else       { $bg = "#E8EBEE"; $tx = "#15181C"; $mu = "#5C6670"; $cd = "#FFFFFF"; $ac = "#F2B01E"; $qb = "#FFF0C4"; $ln = "#D3D8DE" }
    $css = @"
body{background:$bg;color:$tx;font-family:'Segoe UI',Arial,sans-serif;font-size:14px;line-height:1.6;margin:0;padding:22px 34px 40px;max-width:760px;}
h1{font-family:'Bahnschrift SemiBold','Segoe UI Semibold',sans-serif;font-size:28px;margin:0 0 6px;font-weight:normal;}
h2{font-family:'Bahnschrift SemiBold','Segoe UI Semibold',sans-serif;font-size:20px;margin:34px 0 8px;font-weight:normal;padding-top:6px;border-top:3px solid $ac;}
h3{font-family:'Bahnschrift SemiBold','Segoe UI Semibold',sans-serif;font-size:16px;margin:22px 0 4px;font-weight:normal;}
p{margin:8px 0;} li{margin:4px 0;} a{color:$tx;}
code{background:$cd;border:1px solid $ln;padding:0 5px;border-radius:4px;font-family:'Cascadia Mono',Consolas,monospace;font-size:12.5px;}
pre{background:$cd;border:1px solid $ln;padding:12px 14px;border-radius:6px;font-family:'Cascadia Mono',Consolas,monospace;font-size:12.5px;overflow:auto;}
blockquote{margin:14px 0;padding:10px 16px;border-left:4px solid $ac;background:$qb;border-radius:0 6px 6px 0;}
hr{border:0;border-top:1px solid $ln;margin:24px 0;}
"@
    return "<!DOCTYPE html><html><head><meta http-equiv=`"X-UA-Compatible`" content=`"IE=edge`"><meta charset=`"utf-8`"><style>$css</style></head><body>" + $out.ToString() + "</body></html>"
}

function Show-Help {
    $xaml = '<Window Width="940" ShowInTaskbar="False"><Grid x:Name="Host"/></Window>'
    $w = Parse-Xaml $xaml
    $w.Height = (Get-FitHeight 820)
    Initialize-Window $w $script:MainWin
    $w.Title = (T 'help.title')
    $path = Join-Path $script:AppRoot ("docs\GUIDE.{0}.md" -f $script:Lang)
    if (-not (Test-Path -LiteralPath $path)) { $path = Join-Path $script:AppRoot "docs\GUIDE.en.md" }
    $wb = New-Object System.Windows.Controls.WebBrowser
    if (Test-Path -LiteralPath $path) {
        $html = ConvertFrom-MiniMarkdown (Get-Content -LiteralPath $path -Raw -Encoding UTF8) ($script:ThemeMode -eq "dark")
    } else {
        $html = "<html><body><p>" + [System.Net.WebUtility]::HtmlEncode((T 'help.missing' $path)) + "</p></body></html>"
    }
    # links open in the default browser, not inside the help window
    $wb.Add_Navigating({
        param($s, $e)
        if ($e.Uri -and $e.Uri.Scheme -in "http", "https") { $e.Cancel = $true; try { Start-Process $e.Uri.AbsoluteUri } catch {} }
    })
    $w.FindName("Host").Children.Add($wb) | Out-Null
    $wb.NavigateToString($html)
    [void]$w.ShowDialog()
}

function Show-About {
    $xaml = @'
<Window Width="560" SizeToContent="Height" ResizeMode="NoResize" ShowInTaskbar="False">
  <StackPanel Margin="28,26,28,24">
    <StackPanel Orientation="Horizontal">
      <ContentControl x:Name="LogoHost"/>
      <StackPanel Margin="16,0,0,0" VerticalAlignment="Center">
        <TextBlock x:Name="AppName" Style="{StaticResource Display}" FontSize="28"/>
        <TextBlock x:Name="Version" Style="{StaticResource Muted}"/>
      </StackPanel>
    </StackPanel>
    <TextBlock x:Name="Desc" Style="{StaticResource Muted}" Margin="0,18,0,0"/>
    <StackPanel x:Name="TagHost" Orientation="Horizontal" Margin="0,12,0,0"/>
    <Border Style="{StaticResource Card}" Margin="0,20,0,0">
      <StackPanel>
        <TextBlock x:Name="CreditsTitle" Style="{StaticResource Title}" Margin="0,0,0,8"/>
        <TextBlock x:Name="Credits" TextWrapping="Wrap" LineHeight="21"/>
      </StackPanel>
    </Border>
    <TextBlock x:Name="License" Style="{StaticResource Muted}" FontSize="12" Margin="0,16,0,0"/>
    <TextBlock x:Name="Trademarks" Style="{StaticResource Muted}" FontSize="12" Margin="0,8,0,0"/>
    <Button x:Name="BtnClose" Style="{StaticResource PrimaryButton}" HorizontalAlignment="Right" Margin="0,20,0,0" MinWidth="110" IsDefault="True" IsCancel="True"/>
  </StackPanel>
</Window>
'@
    $w = Parse-Xaml $xaml
    Initialize-Window $w $script:MainWin
    $w.Title = (T 'about.title')
    $w.FindName("LogoHost").Content = (New-Logo 64)
    $w.FindName("AppName").Text = $script:AppName
    $w.FindName("Version").Text = (T 'about.version' $script:AppVersion)
    $w.FindName("Desc").Text = (T 'app.subtitle')
    [void]$w.FindName("TagHost").Children.Add((New-Tag (T 'about.android') "E8EA" "accent"))
    $w.FindName("CreditsTitle").Text = (T 'about.credits_title')
    $w.FindName("Credits").Text = (T 'about.credits')
    $w.FindName("License").Text = (T 'about.license')
    $w.FindName("Trademarks").Text = (T 'about.trademarks')
    $b = $w.FindName("BtnClose"); $b.Content = (T 'btn.close')
    $script:AboutWin = $w
    $b.Add_Click({ $script:AboutWin.Close() })
    [void]$w.ShowDialog()
}
