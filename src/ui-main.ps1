# ui-main.ps1 - the main window (WPF): phone card, rule cards, run bar with the film-strip progress, log

$script:Config     = $null
$script:History    = @{}
$script:UI         = @{}
$script:Loading    = $false
$script:shell      = $null
$script:Strip      = $null

# sync job state
$script:sync = $null; $script:ps = $null; $script:rs = $null; $script:handle = $null
$script:watch = $null; $script:sel = @(); $script:timer = $null

# ---------------------------------------------------------------- small helpers
function Write-Log($msg) {
    $script:UI.Log.AppendText(("[{0:HH:mm:ss}] {1}`r`n" -f (Get-Date), $msg))
    $script:UI.Log.ScrollToEnd()
}
function Set-Status($phase, $detail) { $script:UI.PhaseText.Text = $phase; $script:UI.StatusText.Text = $detail }
function Get-PhoneName { if ($script:UI.PhoneCombo.SelectedIndex -ge 0) { return [string]$script:UI.PhoneCombo.SelectedItem }; return $null }
function Save-AppConfig {
    if (-not (Save-Config $script:Config)) { [void](Show-Message (T 'main.err_save' $script:ConfigPath) "warn") }
}
function Get-RuleById($id) { @($script:Config.rules) | Where-Object { $_.id -eq $id } | Select-Object -First 1 }

# ---------------------------------------------------------------- phone card
function Get-Phones {
    $list = @($script:shell.NameSpace(17).Items() | Where-Object { -not $_.IsFileSystem })
    # developer test mode: a PC folder acts as a phone (SINCRONIZZAFOTO_FAKE_PHONE=<folder>)
    if ($env:SINCRONIZZAFOTO_FAKE_PHONE -and (Test-Path -LiteralPath $env:SINCRONIZZAFOTO_FAKE_PHONE)) {
        $fakeName = if ($env:SINCRONIZZAFOTO_FAKE_PHONE_NAME) { $env:SINCRONIZZAFOTO_FAKE_PHONE_NAME } else { "Fake phone (test)" }
        $list += [pscustomobject]@{ Name = $fakeName }
    }
    return $list
}

function Update-PhoneCard {
    $name = Get-PhoneName
    $av = $script:UI.Avatar
    if ($name) {
        $ios = ($name -match 'iPhone|iPad|iPod')
        $av.SetResourceReference([System.Windows.Controls.Border]::BackgroundProperty, $(if ($ios) { "B.WarnSoft" } else { "B.SuccessSoft" }))
        $av.Child = New-Icon $(if ($ios) { "E7BA" } else { "E8EA" }) 22 $(if ($ios) { "B.Warn" } else { "B.Success" })
        $script:UI.PhoneTitle.Text = $name
        $script:UI.PhoneSub.Text = $(if ($ios) { T 'main.ios_warn' } else { T 'main.phone_ready' })
    } else {
        $av.SetResourceReference([System.Windows.Controls.Border]::BackgroundProperty, "B.SurfaceAlt")
        $av.Child = New-Icon "E8EA" 22 "B.Muted"
        $script:UI.PhoneTitle.Text = (T 'main.no_phone_title')
        $script:UI.PhoneSub.Text = (T 'main.no_phone_found')
    }
}

function Refresh-Phones {
    $names = @(Get-Phones | ForEach-Object { $_.Name })
    $cb = $script:UI.PhoneCombo
    $script:Loading = $true
    $cb.Items.Clear()
    foreach ($n in $names) { [void]$cb.Items.Add($n) }
    if ($names.Count -gt 0) { $cb.SelectedIndex = 0 }
    $script:Loading = $false
    $cb.Visibility = $(if ($names.Count -gt 1) { "Visible" } else { "Collapsed" })
    Update-PhoneCard
}

# ---------------------------------------------------------------- rule cards
function Get-OrgShortKey($org) { "org.$org.short" }

function New-RuleCard($rule) {
    $xaml = @'
<Border Style="{StaticResource Card}" Padding="14" Margin="0,0,0,10">
  <Grid>
    <Grid.ColumnDefinitions><ColumnDefinition Width="Auto"/><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
    <Border x:Name="IconTile" Width="46" Height="46" CornerRadius="6" Background="{DynamicResource B.AccentSoft}" BorderBrush="{DynamicResource B.Accent}" BorderThickness="1" Margin="0,0,16,0" VerticalAlignment="Top"/>
    <StackPanel Grid.Column="1" VerticalAlignment="Center" Margin="0,0,12,0">
      <TextBlock x:Name="RName" Style="{StaticResource Title}" TextTrimming="CharacterEllipsis"/>
      <TextBlock x:Name="RPath" Style="{StaticResource Mono}" Foreground="{DynamicResource B.Muted}" TextTrimming="CharacterEllipsis" Margin="0,3,0,0"/>
      <WrapPanel x:Name="RTags" Margin="0,9,0,0"/>
    </StackPanel>
    <StackPanel Grid.Column="2" Orientation="Horizontal" VerticalAlignment="Center">
      <StackPanel x:Name="RSync" Orientation="Horizontal" Margin="0,0,18,0" VerticalAlignment="Center"/>
      <CheckBox x:Name="REnabled" Style="{StaticResource Switch}" Margin="0,0,12,0"/>
      <Button x:Name="RPlay" Style="{StaticResource IconButton}"/>
      <Button x:Name="RTidy" Style="{StaticResource IconButton}"/>
      <Button x:Name="REdit" Style="{StaticResource IconButton}"/>
      <Button x:Name="RDelete" Style="{StaticResource DangerIconButton}"/>
    </StackPanel>
  </Grid>
</Border>
'@
    $card = Parse-Xaml $xaml
    $card.FindName("IconTile").Child = (New-Icon (Get-RuleIconCode $rule) 20 "B.AccentInk")
    $card.FindName("RName").Text = $rule.name
    $card.FindName("RPath").Text = ("{0}   {1}   {2}" -f $rule.phoneFolder, [char]0x2192, (Expand-Path $rule.destFolder))
    $card.FindName("RPath").ToolTip = (Expand-Path $rule.destFolder)

    # tags: what / how / subfolders
    $tags = $card.FindName("RTags")
    $types = @($rule.fileTypes); $exts = @($rule.extensions)
    if ($types.Count -eq 0 -and $exts.Count -eq 0) { [void]$tags.Children.Add((New-Tag (T 'tag.all') "E8C8" "accent")) }
    else {
        $icons = @{ photos = "EB9F"; videos = "E714"; audio = "E8D6"; documents = "E8A5" }
        foreach ($t in $types) { [void]$tags.Children.Add((New-Tag (T "type.$t") $icons[$t] "accent")) }
        foreach ($e in $exts)  { [void]$tags.Children.Add((New-Tag (".$e") "" "accent")) }
    }
    [void]$tags.Children.Add((New-Tag (T (Get-OrgShortKey $rule.organization)) "ED25"))
    if ($rule.includeSubfolders) { [void]$tags.Children.Add((New-Tag (T 'tag.subfolders') "E8FD")) }

    # last sync
    $sync = $card.FindName("RSync")
    $last = Format-LastSync $rule.id
    $has = $script:History.ContainsKey($rule.id)
    if ($has) { $ic = New-Icon "E73E" 13 "B.Success"; $ic.Margin = New-Object System.Windows.Thickness(0, 0, 6, 0); [void]$sync.Children.Add($ic) }
    $tb = New-Object System.Windows.Controls.TextBlock; $tb.Text = $last; $tb.VerticalAlignment = "Center"
    $tb.SetResourceReference([System.Windows.Controls.TextBlock]::ForegroundProperty, $(if ($has) { "B.Success" } else { "B.Muted" }))
    [void]$sync.Children.Add($tb)

    $sw = $card.FindName("REnabled"); $sw.IsChecked = [bool]$rule.enabled; $sw.Tag = $rule.id
    Set-A11yName $sw ((T 'tip.enable') + ": " + $rule.name)
    $sw.Add_Click({ param($s, $e) $r = Get-RuleById $s.Tag; if ($r) { $r.enabled = [bool]$s.IsChecked; Save-AppConfig } })
    $pl = $card.FindName("RPlay"); $pl.Content = (New-Icon "E768" 16); $pl.Tag = $rule.id; $pl.ToolTip = (T 'tip.play'); Set-A11yName $pl ((T 'tip.play') + ": " + $rule.name)
    $pl.Add_Click({ param($s, $e) Start-Sync $s.Tag })
    $ti = $card.FindName("RTidy"); $ti.Content = (New-Icon "E8CB" 16); $ti.Tag = $rule.id; Set-A11yName $ti ((T 'tip.reorg') + ": " + $rule.name)
    $ti.Add_Click({ param($s, $e) $r = Get-RuleById $s.Tag; if ($r) { [void](Show-Reorganize $r ""); Refresh-RuleCards } })
    $ed = $card.FindName("REdit"); $ed.Content = (New-Icon "E70F" 16); $ed.Tag = $rule.id; Set-A11yName $ed ((T 'btn.edit') + " " + $rule.name)
    $ed.Add_Click({ param($s, $e) Edit-RuleAction $s.Tag })
    $de = $card.FindName("RDelete"); $de.Content = (New-Icon "E74D" 16); $de.Tag = $rule.id; Set-A11yName $de ((T 'btn.delete') + " " + $rule.name)
    $de.Add_Click({ param($s, $e) Delete-RuleAction $s.Tag })
    $card.Tag = $rule.id
    $card.Add_MouseLeftButtonDown({ param($s, $e) if ($e.ClickCount -eq 2) { Edit-RuleAction $s.Tag } })
    return $card
}

function Refresh-RuleCards {
    $panel = $script:UI.RulesPanel
    $panel.Children.Clear()
    $rules = @($script:Config.rules)
    if ($rules.Count -eq 0) {
        $xaml = @'
<Border Style="{StaticResource Card}" Padding="28">
  <StackPanel HorizontalAlignment="Center" MaxWidth="460">
    <Border x:Name="EIcon" Width="56" Height="56" CornerRadius="28" Background="{DynamicResource B.AccentSoft}" HorizontalAlignment="Center"/>
    <TextBlock x:Name="ETitle" Style="{StaticResource Title}" HorizontalAlignment="Center" Margin="0,14,0,4"/>
    <TextBlock x:Name="EText" Style="{StaticResource Muted}" TextAlignment="Center"/>
    <Button x:Name="EBtn" Style="{StaticResource PrimaryButton}" HorizontalAlignment="Center" Margin="0,16,0,0" FontSize="14"/>
  </StackPanel>
</Border>
'@
        $e = Parse-Xaml $xaml
        $e.FindName("EIcon").Child = (New-Icon "ED25" 24 "B.AccentInk")
        $e.FindName("ETitle").Text = (T 'main.empty_title')
        $e.FindName("EText").Text = (T 'main.empty_text')
        $b = $e.FindName("EBtn"); Set-IconLabel $b "E945" (T 'btn.quick'); $b.Add_Click({ QuickSetup-Action })
        [void]$panel.Children.Add($e)
        return
    }
    foreach ($r in $rules) { [void]$panel.Children.Add((New-RuleCard $r)) }
}

# ---------------------------------------------------------------- rule actions
function Add-RuleAction {
    $res = Show-RuleEditor (New-Rule) 'editor.title_add' (Get-PhoneName)
    if ($res) { $script:Config.rules = @($script:Config.rules) + $res; Save-AppConfig; Refresh-RuleCards }
}
function Edit-RuleAction($id) {
    $r = Get-RuleById $id; if (-not $r) { return }
    $res = Show-RuleEditor $r 'editor.title_edit' (Get-PhoneName)
    if ($res) {
        $oldDest = Expand-Path $r.destFolder; $newDest = Expand-Path $res.destFolder
        $oldOrg = $r.organization
        $script:Config.rules = @(@($script:Config.rules) | ForEach-Object { if ($_.id -eq $id) { $res } else { $_ } })
        Save-AppConfig; Refresh-RuleCards

        # the structure or the folder changed: offer to bring the files already copied along
        $destChanged = ($oldDest.TrimEnd('\') -ine $newDest.TrimEnd('\'))
        $orgChanged = ($oldOrg -ne $res.organization)
        if (($destChanged -or $orgChanged) -and $res.organization -ne "mirror" -and (Test-Path -LiteralPath $oldDest) -and
            (Get-ChildItem -LiteralPath $oldDest -File -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1)) {
            $q = if ($destChanged) { T 'reorg.ask_dest' } else { T 'reorg.ask_changed' }
            if ((Show-Message $q "question" "YesNo") -eq "Yes") {
                [void](Show-Reorganize $res $(if ($destChanged) { $oldDest } else { "" }))
                Refresh-RuleCards
            }
        }
    }
}
function Delete-RuleAction($id) {
    $r = Get-RuleById $id; if (-not $r) { return }
    if ((Show-Message (T 'main.delete_confirm' $r.name) "question" "YesNo") -ne "Yes") { return }
    $script:Config.rules = @(@($script:Config.rules) | Where-Object { $_.id -ne $id })
    $script:History.Remove($id); Save-History $script:History
    Save-AppConfig; Refresh-RuleCards
}
function QuickSetup-Action {
    $new = Show-QuickSetup
    if ($new) { $script:Config.rules = @($script:Config.rules) + @($new); Save-AppConfig; Refresh-RuleCards }
}
function Export-Action {
    if (@($script:Config.rules).Count -eq 0) { [void](Show-Message (T 'main.nothing_to_export')); return }
    $dlg = New-Object Microsoft.Win32.SaveFileDialog
    $dlg.Filter = "JSON (*.json)|*.json"; $dlg.FileName = "SincronizzaFoto-rules.json"; $dlg.Title = (T 'main.export_title')
    if ($dlg.ShowDialog($script:MainWin) -eq $true) {
        try { Export-Rules $dlg.FileName $script:Config.rules; [void](Show-Message (T 'main.exported' $dlg.FileName)) }
        catch { [void](Show-Message (T 'main.import_err' $_.Exception.Message) "warn") }
    }
}
function Import-Action {
    $dlg = New-Object Microsoft.Win32.OpenFileDialog
    $dlg.Filter = "JSON (*.json)|*.json"; $dlg.Title = (T 'main.import_title')
    if ($dlg.ShowDialog($script:MainWin) -ne $true) { return }
    try {
        $new = @(Import-Rules $dlg.FileName)
        if ($new.Count -eq 0) { [void](Show-Message (T 'main.import_none') "warn"); return }
        $script:Config.rules = @($script:Config.rules) + $new
        Save-AppConfig; Refresh-RuleCards
        [void](Show-Message (T 'main.imported_n' $new.Count))
    } catch { [void](Show-Message (T 'main.import_err' $_.Exception.Message) "warn") }
}

# ---------------------------------------------------------------- sync job
function Save-RuleResults($sel, $stats) {
    foreach ($rule in $sel) {
        $st = $stats[$rule.Id]
        if ($st -and $st.Found -and $st.Done -ge $st.Total) {
            $script:History[$rule.Id] = @{ Last = (Get-Date).ToString("s"); Copied = $st.Copied; Skipped = $st.Skipped; Failed = $st.Failed }
            Write-Log (T 'res.ok' $rule.Name $st.Copied $st.Skipped $st.Failed)
        } elseif ($st -and -not $st.Found) { Write-Log (T 'res.notfound' $rule.Name) }
        elseif ($st) { Write-Log (T 'res.partial' $rule.Name $st.Done $st.Total) }
    }
    Save-History $script:History
}

function Drain-Log {
    $s = $script:sync
    while ($s.Log.Count -gt 0) { $script:UI.Log.AppendText(([string]$s.Log.Dequeue()) + "`r`n") }
    $script:UI.Log.ScrollToEnd()
}

function Set-Running([bool]$running) {
    $script:UI.StartBtn.IsEnabled = -not $running
    $script:UI.StopBtn.IsEnabled = $running
    $script:UI.RuleTools.IsEnabled = -not $running
    $script:UI.RulesPanel.IsEnabled = -not $running
    $script:UI.RefreshBtn.IsEnabled = -not $running
    $script:UI.PhoneCombo.IsEnabled = -not $running
}

function Finish-Sync {
    $script:timer.Stop()
    $s = $script:sync
    Drain-Log
    try { [void]$script:ps.EndInvoke($script:handle) } catch {}
    try { $script:ps.Dispose(); $script:rs.Close(); $script:rs.Dispose() } catch {}
    $script:watch.Stop()
    $el = $script:watch.Elapsed.ToString('hh\:mm\:ss')

    if ($s.Outcome -eq "ok") { Set-FilmProgress $script:Strip 1.0 } else { Set-FilmProgress $script:Strip 0.0 }
    if ($s.Outcome -in "ok", "cancel", "empty") { Write-Log "---"; Save-RuleResults $script:sel $s.Stats }
    Refresh-RuleCards
    switch ($s.Outcome) {
        "ok"          { Set-Status (T 'main.done') (T 'main.done_detail' $s.Copied $s.Skipped $s.Failed $el)
                        Write-Log (T 'main.completed'); Write-Log (T 'main.summary' $s.Copied $s.Skipped $s.Failed) }
        "empty"       { Set-Status (T 'main.done') (T 'main.nothing') }
        "cancel"      { Set-Status (T 'main.stopped') (T 'main.stopped_detail' $el) }
        "cancel-read" { Set-Status (T 'main.stopped') (T 'main.stopped_read') }
        default       { Set-Status (T 'main.error') "$($s.Error)" }
    }
    Set-Running $false
}

function Start-Sync([string]$onlyRuleId = "") {
    if (-not (Get-PhoneName)) { [void](Show-Message (T 'main.no_phone')); return }
    if (@($script:Config.rules).Count -eq 0) { [void](Show-Message (T 'main.no_rules')); return }
    # a single rule (its own play button) runs even if its switch is off; otherwise all the enabled ones
    $sel = @(@($script:Config.rules) | Where-Object { if ($onlyRuleId) { $_.id -eq $onlyRuleId } else { $_.enabled } } | ForEach-Object { ConvertTo-WorkerRule $_ })
    if ($sel.Count -eq 0) { [void](Show-Message (T 'main.nothing_selected')); return }

    $script:sel = $sel
    $script:sync = [hashtable]::Synchronized(@{
        Cancel = $false; Phase = (T 'main.starting'); Status = ""; Marquee = $true; Max = 0; Value = 0; FileFraction = 0.0
        Done = $false; Outcome = ""; Error = ""; Copied = 0; Skipped = 0; Failed = 0
        Stats = [hashtable]::Synchronized(@{})
        Log   = [System.Collections.Queue]::Synchronized((New-Object System.Collections.Queue))
    })
    $script:UI.Log.Clear()
    $script:UI.LogToggle.IsChecked = $true; $script:UI.Log.Visibility = "Visible"   # show the log while copying
    Set-Running $true
    Set-FilmBusy $script:Strip $true

    $script:rs = [runspacefactory]::CreateRunspace()
    $script:rs.ApartmentState = "STA"; $script:rs.ThreadOptions = "ReuseThread"; $script:rs.Open()
    $script:ps = [powershell]::Create(); $script:ps.Runspace = $script:rs
    [void]$script:ps.AddScript($script:WorkerScript.ToString()).AddArgument($script:sync).AddArgument($sel).AddArgument([string](Get-PhoneName)).AddArgument([bool]$script:UI.SkipSwitch.IsChecked).AddArgument($script:Strings)
    $script:watch = [Diagnostics.Stopwatch]::StartNew()
    $script:handle = $script:ps.BeginInvoke()
    $script:timer.Start()
}

function Update-SyncUi {
    $s = $script:sync
    if (-not $s) { return }
    Drain-Log
    if ($s.Done) { Finish-Sync; return }
    $el = $script:watch.Elapsed.ToString('hh\:mm\:ss')
    $phase = if ($s.Cancel) { T 'main.cancelling' } else { [string]$s.Phase }
    $script:UI.PhaseText.Text = "$phase   [$el]"
    $script:UI.StatusText.Text = [string]$s.Status
    if ($s.Marquee) { Set-FilmBusy $script:Strip $true }
    elseif ($s.Max -gt 0) {
        # files done so far plus the part of the current one already transferred (smooth with big videos)
        $done = [Math]::Max(0.0, [double]$s.Value - 1.0) + [double]$s.FileFraction
        Set-FilmProgress $script:Strip ($done / [double]$s.Max)
    }
}

# ---------------------------------------------------------------- texts, language, theme
function Set-MainTexts {
    $u = $script:UI
    $script:MainWin.Title = (T 'app.title')
    $u.SubText.Text = (T 'app.subtitle')
    $u.RulesTitle.Text = (T 'main.rules_title')
    $u.RulesHint.Text = (T 'main.rules_hint')
    Set-IconLabel $u.QuickBtn "E945" (T 'btn.quick')
    Set-IconLabel $u.AddBtn "E710" (T 'btn.add')
    Set-IconLabel $u.ImportBtn "E896" (T 'btn.import')
    Set-IconLabel $u.ExportBtn "E898" (T 'btn.export')
    Set-IconLabel $u.RefreshBtn "E72C" (T 'btn.refresh')
    Set-IconLabel $u.StartBtn "E768" (T 'btn.start') 15
    Set-IconLabel $u.StopBtn "E71A" (T 'btn.stop') 13
    $u.SkipSwitch.Content = (T 'main.show_skipped')
    Set-IconLabel $u.LogToggle "E756" (T 'btn.log') 13
    $u.LangAuto.Content = (T 'lang.auto')
    $u.HelpBtn.Content = (New-Icon "E897" 16); Set-A11yName $u.HelpBtn (T 'btn.help')
    $u.AboutBtn.Content = (New-Icon "E946" 16); Set-A11yName $u.AboutBtn (T 'btn.about')
    $u.AndroidTag.Children.Clear()
    [void]$u.AndroidTag.Children.Add((New-Tag (T 'main.android_chip') "E8EA" "accent"))
    Update-ThemeButton
}

function Update-ThemeButton {
    $mode = $script:Config.theme
    $glyph = switch ($mode) { "light" { "E706" } "dark" { "E708" } default { "E7F4" } }
    $script:UI.ThemeBtn.Content = (New-Icon $glyph 16)
    Set-A11yName $script:UI.ThemeBtn (T "theme.$mode")
}

function Set-AppLanguage($code) {
    if ($script:Loading) { return }
    $script:Config.language = $code
    Save-AppConfig
    Set-Language $code
    Set-MainTexts
    Refresh-RuleCards
    if (-not $script:sync -or $script:sync.Done) { Update-PhoneCard; Set-Status (T 'main.ready') "" }
}

function Cycle-Theme {
    $next = switch ($script:Config.theme) { "auto" { "light" } "light" { "dark" } default { "auto" } }
    $script:Config.theme = $next
    Save-AppConfig
    Set-Theme $next
    Update-ThemeButton
}

# ---------------------------------------------------------------- window
function Build-MainWindow {
    $xaml = @'
<Window x:Name="Win" Width="1060" Height="900" MinWidth="920" MinHeight="740">
  <Grid Margin="30,24,30,24">
    <Grid.RowDefinitions>
      <RowDefinition Height="Auto"/><RowDefinition Height="Auto"/><RowDefinition Height="Auto"/><RowDefinition Height="*"/><RowDefinition Height="Auto"/>
    </Grid.RowDefinitions>

    <DockPanel Grid.Row="0" Margin="0,0,0,20">
      <StackPanel DockPanel.Dock="Right" Orientation="Horizontal" VerticalAlignment="Center">
        <Border Background="{DynamicResource B.SurfaceAlt}" CornerRadius="8" Padding="3" Margin="0,0,10,0">
          <StackPanel Orientation="Horizontal">
            <RadioButton x:Name="LangAuto" Style="{StaticResource Segment}" GroupName="lang"/>
            <RadioButton x:Name="LangIt" Style="{StaticResource Segment}" GroupName="lang" Content="IT"/>
            <RadioButton x:Name="LangEn" Style="{StaticResource Segment}" GroupName="lang" Content="EN"/>
          </StackPanel>
        </Border>
        <Button x:Name="ThemeBtn" Style="{StaticResource IconButton}"/>
        <Button x:Name="HelpBtn" Style="{StaticResource IconButton}"/>
        <Button x:Name="AboutBtn" Style="{StaticResource IconButton}"/>
      </StackPanel>
      <StackPanel Orientation="Horizontal">
        <ContentControl x:Name="LogoHost" VerticalAlignment="Center"/>
        <StackPanel Margin="14,0,0,0" VerticalAlignment="Center">
          <TextBlock x:Name="TitleText" Style="{StaticResource Display}" Text="SincronizzaFoto"/>
          <TextBlock x:Name="SubText" Style="{StaticResource Muted}"/>
        </StackPanel>
      </StackPanel>
    </DockPanel>

    <Border Grid.Row="1" Style="{StaticResource Card}" Margin="0,0,0,22">
      <Grid>
        <Grid.ColumnDefinitions><ColumnDefinition Width="Auto"/><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
        <Border x:Name="Avatar" Width="52" Height="52" CornerRadius="26" Margin="0,0,16,0"/>
        <StackPanel Grid.Column="1" VerticalAlignment="Center">
          <TextBlock x:Name="PhoneTitle" Style="{StaticResource Title}"/>
          <TextBlock x:Name="PhoneSub" Style="{StaticResource Muted}" Margin="0,2,0,0"/>
          <StackPanel x:Name="AndroidTag" Orientation="Horizontal" Margin="0,8,0,0"/>
        </StackPanel>
        <ComboBox x:Name="PhoneCombo" Grid.Column="2" Width="200" Margin="12,0,12,0" VerticalAlignment="Center" Visibility="Collapsed"/>
        <Button x:Name="RefreshBtn" Grid.Column="3" VerticalAlignment="Center"/>
      </Grid>
    </Border>

    <DockPanel Grid.Row="2" Margin="0,0,0,12">
      <StackPanel x:Name="RuleTools" DockPanel.Dock="Right" Orientation="Horizontal">
        <Button x:Name="ImportBtn" Margin="0,0,8,0"/><Button x:Name="ExportBtn" Margin="0,0,8,0"/>
        <Button x:Name="QuickBtn" Margin="0,0,8,0"/><Button x:Name="AddBtn"/>
      </StackPanel>
      <StackPanel VerticalAlignment="Center">
        <TextBlock x:Name="RulesTitle" Style="{StaticResource Title}"/>
        <TextBlock x:Name="RulesHint" Style="{StaticResource Muted}" FontSize="12"/>
      </StackPanel>
    </DockPanel>

    <ScrollViewer Grid.Row="3" VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Disabled" MinHeight="140" Margin="0,0,0,18">
      <StackPanel x:Name="RulesPanel" Margin="0,0,6,0"/>
    </ScrollViewer>

    <Border Grid.Row="4" Style="{StaticResource Card}">
      <StackPanel>
        <DockPanel Margin="0,0,0,14">
          <CheckBox x:Name="SkipSwitch" DockPanel.Dock="Right" Style="{StaticResource Switch}" VerticalAlignment="Center"/>
          <StackPanel Orientation="Horizontal">
            <Button x:Name="StartBtn" Style="{StaticResource PrimaryButton}" Margin="0,0,10,0"/>
            <Button x:Name="StopBtn" IsEnabled="False" Padding="16,10"/>
          </StackPanel>
        </DockPanel>
        <ContentControl x:Name="StripHost"/>
        <TextBlock x:Name="PhaseText" Style="{StaticResource Title}" Margin="0,14,0,2"/>
        <TextBlock x:Name="StatusText" Style="{StaticResource Muted}" MinHeight="34"/>
        <ToggleButton x:Name="LogToggle" Style="{StaticResource Chip}" IsChecked="False" HorizontalAlignment="Left" Margin="0,8,0,0"/>
        <TextBox x:Name="Log" IsReadOnly="True" Height="150" TextWrapping="Wrap" FontFamily="{StaticResource F.Mono}" FontSize="12" Margin="0,8,0,0" Visibility="Collapsed"
                 VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Disabled" VerticalContentAlignment="Top"/>
      </StackPanel>
    </Border>
  </Grid>
</Window>
'@
    $win = Parse-Xaml $xaml
    $script:MainWin = $win
    Initialize-Window $win
    $names = "LangAuto", "LangIt", "LangEn", "ThemeBtn", "HelpBtn", "AboutBtn", "LogoHost", "TitleText", "SubText", "Avatar", "PhoneTitle", "PhoneSub", "AndroidTag",
             "PhoneCombo", "RefreshBtn", "RuleTools", "ImportBtn", "ExportBtn", "QuickBtn", "AddBtn", "RulesTitle", "RulesHint", "RulesPanel",
             "SkipSwitch", "StartBtn", "StopBtn", "StripHost", "PhaseText", "StatusText", "LogToggle", "Log"
    foreach ($n in $names) { $script:UI[$n] = $win.FindName($n) }

    $script:UI.LogoHost.Content = (New-Logo 46)
    $script:Strip = New-FilmStrip
    $script:UI.StripHost.Content = $script:Strip.Root

    # sync timer (UI thread) - mirrors the background job into the window
    $script:timer = New-Object System.Windows.Threading.DispatcherTimer
    $script:timer.Interval = [TimeSpan]::FromMilliseconds(200)
    $script:timer.Add_Tick({ Update-SyncUi })

    # events
    $script:UI.HelpBtn.Add_Click({ Show-Help })
    $script:UI.AboutBtn.Add_Click({ Show-About })
    $script:UI.ThemeBtn.Add_Click({ Cycle-Theme })
    $script:UI.RefreshBtn.Add_Click({ Refresh-Phones })
    $script:UI.PhoneCombo.Add_SelectionChanged({ if (-not $script:Loading) { Update-PhoneCard } })
    $script:UI.AddBtn.Add_Click({ Add-RuleAction })
    $script:UI.QuickBtn.Add_Click({ QuickSetup-Action })
    $script:UI.ImportBtn.Add_Click({ Import-Action })
    $script:UI.ExportBtn.Add_Click({ Export-Action })
    $script:UI.StartBtn.Add_Click({ Start-Sync })
    $script:UI.StopBtn.Add_Click({ if ($script:sync) { $script:sync.Cancel = $true } })
    $script:UI.LangAuto.Add_Checked({ Set-AppLanguage "auto" })
    $script:UI.LangIt.Add_Checked({ Set-AppLanguage "it" })
    $script:UI.LangEn.Add_Checked({ Set-AppLanguage "en" })
    $script:UI.LogToggle.Add_Click({
        $script:UI.Log.Visibility = $(if ($script:UI.LogToggle.IsChecked) { "Visible" } else { "Collapsed" })
    })
    $win.Add_Closing({ if ($script:sync) { $script:sync.Cancel = $true } })
    $win.Add_ContentRendered({ if (-not $script:Rendered) { $script:Rendered = $true; Invoke-FirstRun } })

    # initial state
    $script:Loading = $true
    switch ($script:Config.language) { "it" { $script:UI.LangIt.IsChecked = $true } "en" { $script:UI.LangEn.IsChecked = $true } default { $script:UI.LangAuto.IsChecked = $true } }
    $script:Loading = $false
    Set-MainTexts
    Set-Status (T 'main.ready') ""
    Refresh-RuleCards
    Refresh-Phones
}

# first run: explain what happened (Excel import) or offer the quick setup
function Invoke-FirstRun {
    if ($script:ConfigWarning) {
        [void](Show-Message (T 'main.config_broken' $script:ConfigWarning) "warn")
        $script:ConfigWarning = $null
    }
    if ($script:ImportedLegacy -gt 0) {
        [void](Show-Message (T 'main.imported_legacy' $script:ImportedLegacy))
        $script:ImportedLegacy = 0
    }
    elseif (@($script:Config.rules).Count -eq 0) {
        if ((Show-Message (T 'main.welcome') "question" "YesNo") -eq "Yes") { QuickSetup-Action }
    }
}

function Start-App {
    Initialize-DataDir
    $script:Config  = Load-Config
    # an unreadable config.json is set aside (never silently overwritten) and the user is told
    $script:ConfigWarning = $null
    if ($script:ConfigError) {
        try {
            $bak = Join-Path $script:DataDir ("config.broken-{0:yyyyMMdd-HHmmss}.json" -f (Get-Date))
            Move-Item -LiteralPath $script:ConfigPath -Destination $bak -Force
            $script:ConfigWarning = $bak
        } catch {}
    }
    Set-Language $script:Config.language
    $script:History = Load-History
    $script:shell   = New-Object -ComObject Shell.Application

    # one-time migration from the old Excel file
    $script:ImportedLegacy = 0
    $xlsx = Join-Path $script:AppRoot "Sincronizza.xlsx"
    if (-not (Test-Path -LiteralPath $script:ConfigPath) -and (Test-Path -LiteralPath $xlsx)) {
        try {
            $rules = @(Import-LegacyExcel $xlsx)
            if ($rules.Count -gt 0) {
                $script:Config.rules = $rules
                Save-Config $script:Config | Out-Null
                Import-LegacyHistory $rules
                $script:ImportedLegacy = $rules.Count
            }
        } catch {}
    }

    Initialize-Wpf
    Set-Theme $script:Config.theme
    Build-MainWindow
    [void]$script:MainWin.ShowDialog()
    # leave even if the background job is stuck waiting for the phone
    [Environment]::Exit(0)
}
