# ui-rule.ps1 - the rule editor (WPF) and the organization option cards shared with the quick setup

$script:ED = @{}

# ---------------------------------------------------------------- mini folder-tree picture for each organization option
function New-TreeRow([int]$indent, [string]$glyph, [string]$text, [string]$brush) {
    $sp = New-Object System.Windows.Controls.StackPanel
    $sp.Orientation = "Horizontal"; $sp.Margin = New-Object System.Windows.Thickness((14 * $indent), 1, 0, 1)
    $ic = New-Icon $glyph 11 $brush; $ic.Margin = New-Object System.Windows.Thickness(0, 0, 6, 0)
    [void]$sp.Children.Add($ic)
    $tb = New-Object System.Windows.Controls.TextBlock; $tb.Text = $text; $tb.FontSize = 11
    $tb.FontFamily = $script:App.FindResource("F.Mono")
    $tb.SetResourceReference([System.Windows.Controls.TextBlock]::ForegroundProperty, "B.Muted")
    [void]$sp.Children.Add($tb)
    return $sp
}

function New-OrgTree([string]$org) {
    $rows = switch ($org) {
        "year"      { @(@(0, "folder", "Camera"), @(1, "folder", "2026"), @(2, "photo", "IMG_20261117.jpg"), @(1, "folder", "2025"), @(2, "photo", "IMG_20250102.jpg")) }
        "yearMonth" { @(@(0, "folder", "Camera"), @(1, "folder", "2026-11"), @(2, "photo", "IMG_20261117.jpg"), @(1, "folder", "2025-01"), @(2, "photo", "IMG_20250102.jpg")) }
        "mirror"    { @(@(0, "folder", "Camera"), @(1, "photo", "IMG_20261117.jpg"), @(1, "folder", "Trips"), @(2, "photo", "beach.jpg")) }
        default     { @(@(0, "folder", "Camera"), @(1, "photo", "IMG_20261117.jpg"), @(1, "photo", "IMG_20250102.jpg"), @(1, "photo", "beach.jpg")) }
    }
    $panel = New-Object System.Windows.Controls.StackPanel
    $panel.Margin = New-Object System.Windows.Thickness(0, 8, 0, 8)
    foreach ($r in $rows) {
        if ($r[1] -eq "folder") { [void]$panel.Children.Add((New-TreeRow $r[0] "ED25" $r[2] "B.AccentInk")) }
        else { [void]$panel.Children.Add((New-TreeRow $r[0] "EB9F" $r[2] "B.Muted")) }
    }
    return $panel
}

# Four option cards (2 x 2). Returns @{ Root; Radios }. The caller attaches Checked handlers.
function New-OrgCards([string]$selected, [string]$group) {
    $grid = New-Object System.Windows.Controls.Primitives.UniformGrid
    $grid.Columns = 2
    $radios = @()
    foreach ($o in $script:Organizations) {
        $r = New-Object System.Windows.Controls.RadioButton
        $r.Style = $script:App.FindResource("OptionCard"); $r.GroupName = $group; $r.Tag = $o
        $r.Margin = New-Object System.Windows.Thickness(0, 0, 10, 10)
        $r.VerticalContentAlignment = "Top"
        $sp = New-Object System.Windows.Controls.StackPanel
        $t = New-Object System.Windows.Controls.TextBlock; $t.Text = (T "org.$o.title"); $t.FontWeight = "SemiBold"; $t.TextWrapping = "Wrap"
        [void]$sp.Children.Add($t)
        [void]$sp.Children.Add((New-OrgTree $o))
        $d = New-Object System.Windows.Controls.TextBlock; $d.Text = (T "org.$o.desc"); $d.FontSize = 12; $d.TextWrapping = "Wrap"
        $d.SetResourceReference([System.Windows.Controls.TextBlock]::ForegroundProperty, "B.Muted")
        [void]$sp.Children.Add($d)
        $r.Content = $sp
        $r.IsChecked = ($o -eq $selected)
        [void]$grid.Children.Add($r)
        $radios += $r
    }
    if (-not ($radios | Where-Object { $_.IsChecked })) { $radios[0].IsChecked = $true }
    return @{ Root = $grid; Radios = $radios }
}

function Get-CheckedTag($radios) { ($radios | Where-Object { $_.IsChecked } | Select-Object -First 1).Tag }

# ---------------------------------------------------------------- the editor
function Update-EditorState {
    $e = $script:ED
    if (-not $e.Ready) { return }
    $on = [bool]$e.RadTypes.IsChecked
    foreach ($c in $e.TypeChips) { $c.IsEnabled = $on }
    $e.TxtExt.IsEnabled = $on
    $org = [string](Get-CheckedTag $e.Org.Radios)
    if ($org -eq "mirror") { $e.SwSub.IsChecked = $true }
    $e.ExcludePanel.Visibility = if ($e.SwSub.IsChecked) { "Visible" } else { "Collapsed" }
    $e.Example.Text = (Get-OrgExample $e.TxtDest.Text $org)
}

# Returns the edited rule (a new object) or $null if cancelled. $phoneName is used by "Browse phone".
function Show-RuleEditor($rule, $titleKey, $phoneName) {
    $xaml = @'
<Window Width="800" ResizeMode="NoResize" ShowInTaskbar="False">
  <DockPanel>
    <Border DockPanel.Dock="Bottom" Background="{DynamicResource B.Surface}" BorderBrush="{DynamicResource B.Border}" BorderThickness="0,1,0,0" Padding="26,14">
      <StackPanel Orientation="Horizontal" HorizontalAlignment="Right">
        <Button x:Name="BtnCancel" IsCancel="True" MinWidth="100" Margin="0,0,10,0"/>
        <Button x:Name="BtnSave" Style="{StaticResource PrimaryButton}" MinWidth="120"/>
      </StackPanel>
    </Border>
    <ScrollViewer VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Disabled">
      <StackPanel Margin="26,22,20,22">

        <Border Style="{StaticResource Card}" Margin="0,0,0,14"><StackPanel>
          <TextBlock x:Name="LblName" Style="{StaticResource Title}"/>
          <TextBox x:Name="TxtName" Margin="0,10,0,0"/>
          <TextBlock x:Name="HintName" Style="{StaticResource Muted}" FontSize="12" Margin="0,6,0,0"/>
        </StackPanel></Border>

        <Border Style="{StaticResource Card}" Margin="0,0,0,14"><StackPanel>
          <TextBlock x:Name="LblPhone" Style="{StaticResource Title}"/>
          <DockPanel Margin="0,10,0,0">
            <Button x:Name="BtnBrowsePhone" DockPanel.Dock="Right" Margin="10,0,0,0"/>
            <TextBox x:Name="TxtPhone" FontFamily="{StaticResource F.Mono}"/>
          </DockPanel>
          <WrapPanel x:Name="Presets" Margin="0,10,0,0"/>
          <TextBlock x:Name="HintPhone" Style="{StaticResource Muted}" FontSize="12" Margin="0,4,0,0"/>
        </StackPanel></Border>

        <Border Style="{StaticResource Card}" Margin="0,0,0,14"><StackPanel>
          <TextBlock x:Name="LblDest" Style="{StaticResource Title}"/>
          <DockPanel Margin="0,10,0,0">
            <Button x:Name="BtnBrowseDest" DockPanel.Dock="Right" Margin="10,0,0,0"/>
            <TextBox x:Name="TxtDest" FontFamily="{StaticResource F.Mono}"/>
          </DockPanel>
          <TextBlock x:Name="HintDest" Style="{StaticResource Muted}" FontSize="12" Margin="0,6,0,0"/>
        </StackPanel></Border>

        <Border Style="{StaticResource Card}" Margin="0,0,0,14"><StackPanel>
          <TextBlock x:Name="LblWhat" Style="{StaticResource Title}"/>
          <UniformGrid Columns="2" Margin="0,10,0,0">
            <RadioButton x:Name="RadAll" Style="{StaticResource OptionCard}" GroupName="what" Margin="0,0,10,0" Padding="12"/>
            <RadioButton x:Name="RadTypes" Style="{StaticResource OptionCard}" GroupName="what" Padding="12"/>
          </UniformGrid>
          <WrapPanel x:Name="TypeChips" Margin="0,12,0,0"/>
          <DockPanel Margin="0,12,0,0">
            <TextBlock x:Name="LblExt" DockPanel.Dock="Left" VerticalAlignment="Center" Margin="0,0,10,0"/>
            <TextBox x:Name="TxtExt"/>
          </DockPanel>
          <TextBlock x:Name="HintExt" Style="{StaticResource Muted}" FontSize="12" Margin="0,6,0,0"/>
        </StackPanel></Border>

        <Border Style="{StaticResource Card}" Margin="0,0,0,14">
          <StackPanel>
            <DockPanel>
              <CheckBox x:Name="SwSub" DockPanel.Dock="Right" Style="{StaticResource Switch}" VerticalAlignment="Center"/>
              <StackPanel>
                <TextBlock x:Name="LblSub" Style="{StaticResource Title}"/>
                <TextBlock x:Name="HintSub" Style="{StaticResource Muted}" FontSize="12" Margin="0,4,16,0"/>
              </StackPanel>
            </DockPanel>
            <StackPanel x:Name="ExcludePanel" Margin="0,14,0,0">
              <TextBlock x:Name="LblExclude" Style="{StaticResource Title}"/>
              <DockPanel Margin="0,8,0,0">
                <Button x:Name="BtnPickExclude" DockPanel.Dock="Right" Margin="10,0,0,0"/>
                <TextBox x:Name="TxtExclude" FontFamily="{StaticResource F.Mono}"/>
              </DockPanel>
              <TextBlock x:Name="HintExclude" Style="{StaticResource Muted}" FontSize="12" Margin="0,6,0,0"/>
            </StackPanel>
          </StackPanel>
        </Border>

        <Border Style="{StaticResource Card}"><StackPanel>
          <TextBlock x:Name="LblOrg" Style="{StaticResource Title}" Margin="0,0,0,12"/>
          <ContentControl x:Name="OrgHost"/>
          <Border Background="{DynamicResource B.SurfaceAlt}" CornerRadius="6" Padding="12,10" Margin="0,2,10,0">
            <StackPanel>
              <TextBlock x:Name="LblExample" Style="{StaticResource Muted}" FontSize="12"/>
              <TextBlock x:Name="Example" Style="{StaticResource Mono}" Margin="0,4,0,0" TextWrapping="Wrap"/>
            </StackPanel>
          </Border>
        </StackPanel></Border>

      </StackPanel>
    </ScrollViewer>
  </DockPanel>
</Window>
'@
    $w = Parse-Xaml $xaml
    $w.Height = (Get-FitHeight 900)
    Initialize-Window $w $script:MainWin
    $w.Title = (T $titleKey)
    $e = @{ Ready = $false; Window = $w; PhoneName = $phoneName; Rule = $rule }
    foreach ($n in "LblName", "TxtName", "HintName", "LblPhone", "BtnBrowsePhone", "TxtPhone", "Presets", "HintPhone", "LblDest", "BtnBrowseDest", "TxtDest", "HintDest",
                   "LblWhat", "RadAll", "RadTypes", "TypeChips", "LblExt", "TxtExt", "HintExt", "SwSub", "LblSub", "HintSub", "ExcludePanel", "LblExclude", "TxtExclude", "BtnPickExclude", "HintExclude", "LblOrg", "OrgHost", "LblExample", "Example", "BtnCancel", "BtnSave") {
        $e[$n] = $w.FindName($n)
    }
    $script:ED = $e

    # texts
    $e.LblName.Text = (T 'editor.name'); $e.HintName.Text = (T 'editor.name_hint')
    $e.LblPhone.Text = (T 'editor.phone'); $e.HintPhone.Text = (T 'editor.phone_hint')
    Set-IconLabel $e.BtnBrowsePhone "ED25" (T 'editor.browse_phone')
    $e.LblDest.Text = (T 'editor.dest'); $e.HintDest.Text = (T 'editor.dest_hint')
    Set-IconLabel $e.BtnBrowseDest "ED25" (T 'editor.browse')
    $e.LblWhat.Text = (T 'editor.what')
    $e.RadAll.Content = (T 'editor.all'); $e.RadTypes.Content = (T 'editor.only')
    $e.LblExt.Text = (T 'editor.ext'); $e.HintExt.Text = (T 'editor.ext_hint')
    $e.LblSub.Text = (T 'editor.subfolders'); $e.HintSub.Text = (T 'editor.subfolders_hint')
    $e.LblExclude.Text = (T 'editor.exclude'); $e.HintExclude.Text = (T 'editor.exclude_hint')
    Set-IconLabel $e.BtnPickExclude "E710" (T 'editor.exclude_pick')
    $e.LblOrg.Text = (T 'editor.org'); $e.LblExample.Text = (T 'editor.example')
    $e.BtnCancel.Content = (T 'btn.cancel'); $e.BtnSave.Content = (T 'btn.save')

    # values
    $e.TxtName.Text = $rule.name
    $e.TxtPhone.Text = $rule.phoneFolder
    $e.TxtDest.Text = (Expand-Path $rule.destFolder)
    $e.TxtExt.Text = ((@($rule.extensions)) -join ", ")
    $hasFilter = (@($rule.fileTypes).Count -gt 0) -or (@($rule.extensions).Count -gt 0)
    $e.RadAll.IsChecked = -not $hasFilter; $e.RadTypes.IsChecked = $hasFilter
    $e.SwSub.IsChecked = [bool]$rule.includeSubfolders
    $e.TxtExclude.Text = ((@($rule.excludedFolders)) -join ", ")

    # preset chips for the phone folder
    foreach ($p in Get-Presets) {
        $c = New-Object System.Windows.Controls.Button
        $c.Content = (T "preset.$($p.Key)"); $c.Tag = $p.Phone; $c.ToolTip = $p.Phone
        $c.Style = $script:App.FindResource("PresetChip")
        $c.Margin = New-Object System.Windows.Thickness(0, 0, 6, 6)
        $c.Add_Click({ param($s, $ev) $script:ED.TxtPhone.Text = [string]$s.Tag })
        [void]$e.Presets.Children.Add($c)
    }

    # file type chips
    $e.TypeChips = New-Object System.Collections.ArrayList
    $typeIcons = @{ photos = "EB9F"; videos = "E714"; audio = "E8D6"; documents = "E8A5" }
    foreach ($t in "photos", "videos", "audio", "documents") {
        $c = New-Object System.Windows.Controls.Primitives.ToggleButton
        $c.Style = $script:App.FindResource("Chip"); $c.Tag = $t
        Set-IconLabel $c $typeIcons[$t] (T "type.$t") 13
        $c.Margin = New-Object System.Windows.Thickness(0, 0, 8, 0)
        $c.IsChecked = (@($rule.fileTypes) -contains $t)
        [void]$e.TypeChips.Add($c)
    }
    $chipPanel = $w.FindName("TypeChips")
    foreach ($c in $e.TypeChips) { [void]$chipPanel.Children.Add($c) }

    # organization cards
    $e.Org = New-OrgCards ([string]$rule.organization) "org-editor"
    $e.OrgHost.Content = $e.Org.Root
    foreach ($r in $e.Org.Radios) { $r.Add_Checked({ Update-EditorState }) }
    $e.RadAll.Add_Checked({ Update-EditorState }); $e.RadTypes.Add_Checked({ Update-EditorState })
    $e.SwSub.Add_Checked({ Update-EditorState }); $e.SwSub.Add_Unchecked({ Update-EditorState })
    $e.TxtDest.Add_TextChanged({ Update-EditorState })
    $e.Ready = $true
    Update-EditorState

    # actions
    $e.BtnBrowsePhone.Add_Click({
        $ed = $script:ED
        if (-not $ed.PhoneName) { [void](Show-Message (T 'editor.need_phone')); return }
        $sel = Show-PhoneBrowser $ed.PhoneName $ed.TxtPhone.Text $ed.Window
        if ($sel) { $ed.TxtPhone.Text = $sel; if (-not $ed.TxtName.Text.Trim()) { $ed.TxtName.Text = (Split-Path $sel -Leaf) } }
    })
    $e.BtnPickExclude.Add_Click({
        $ed = $script:ED
        if (-not $ed.PhoneName) { [void](Show-Message (T 'editor.need_phone')); return }
        $root = ($ed.TxtPhone.Text.Trim().Trim('\', '/') -replace '/', '\')
        if (-not $root) { [void](Show-Message (T 'editor.err_phone') "warn"); $ed.TxtPhone.Focus() | Out-Null; return }
        $sel = Show-PhoneBrowser $ed.PhoneName $root $ed.Window
        if (-not $sel) { return }
        if ($sel.Length -le $root.Length -or -not $sel.StartsWith($root + "\", [StringComparison]::OrdinalIgnoreCase)) {
            [void](Show-Message (T 'editor.exclude_outside' $root) "warn"); return
        }
        $rel = $sel.Substring($root.Length + 1)
        $cur = @($ed.TxtExclude.Text -split '[,;\r\n]+' | ForEach-Object { $_.Trim() } | Where-Object { $_ })
        if ($cur -notcontains $rel) { $cur += $rel }
        $ed.TxtExclude.Text = ($cur -join ", ")
    })
    $e.BtnBrowseDest.Add_Click({
        $ed = $script:ED
        $p = Select-Folder (T 'editor.browse_dest') $ed.TxtDest.Text
        if ($p) { $ed.TxtDest.Text = $p }
    })
    $script:EditorResult = $null
    $e.BtnSave.Add_Click({
        $ed = $script:ED
        $name = $ed.TxtName.Text.Trim(); $phone = $ed.TxtPhone.Text.Trim(); $dest = $ed.TxtDest.Text.Trim()
        if (-not $name)  { [void](Show-Message (T 'editor.err_name') "warn"); $ed.TxtName.Focus() | Out-Null; return }
        if (-not $phone) { [void](Show-Message (T 'editor.err_phone') "warn"); $ed.TxtPhone.Focus() | Out-Null; return }
        if (-not $dest)  { [void](Show-Message (T 'editor.err_dest') "warn"); $ed.TxtDest.Focus() | Out-Null; return }
        $types = @(); $exts = @()
        if ($ed.RadTypes.IsChecked) {
            foreach ($c in $ed.TypeChips) { if ($c.IsChecked) { $types += [string]$c.Tag } }
            $exts = @($ed.TxtExt.Text -split '[,;\s]+' | Where-Object { $_ } | ForEach-Object { $_.TrimStart('.').ToLower() })
            if ($types.Count -eq 0 -and $exts.Count -eq 0) { [void](Show-Message (T 'editor.err_types') "warn"); return }
        }
        $n = Normalize-Rule $ed.Rule
        $n.name = $name; $n.phoneFolder = ($phone.Trim('\', '/') -replace '/', '\')
        $n.destFolder = (Compress-Path $dest)
        $n.fileTypes = $types; $n.extensions = $exts
        $n.includeSubfolders = [bool]$ed.SwSub.IsChecked
        $n.excludedFolders = @($ed.TxtExclude.Text -split '[,;\r\n]+' | ForEach-Object { $_.Trim().Trim('\', '/') -replace '/', '\' } | Where-Object { $_ })
        $n.organization = [string](Get-CheckedTag $ed.Org.Radios)
        $script:EditorResult = $n
        $ed.Window.DialogResult = $true
    })

    [void]$w.ShowDialog()
    return $script:EditorResult
}
