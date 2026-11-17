# ui-quick.ps1 - quick setup (WPF): tick what to copy, pick one base folder, rules are created for you

$script:QS = @{}

# Returns an array of new rules, or $null if cancelled.
function Show-QuickSetup {
    $xaml = @'
<Window Width="820" ResizeMode="NoResize" ShowInTaskbar="False">
  <DockPanel>
    <Border DockPanel.Dock="Bottom" Background="{DynamicResource B.Surface}" BorderBrush="{DynamicResource B.Border}" BorderThickness="0,1,0,0" Padding="26,14">
      <StackPanel Orientation="Horizontal" HorizontalAlignment="Right">
        <Button x:Name="BtnCancel" IsCancel="True" MinWidth="100" Margin="0,0,10,0"/>
        <Button x:Name="BtnCreate" Style="{StaticResource PrimaryButton}" MinWidth="140"/>
      </StackPanel>
    </Border>
    <ScrollViewer VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Disabled">
      <StackPanel Margin="26,22,20,22">
        <TextBlock x:Name="Intro" Style="{StaticResource Muted}" FontSize="13.5" Margin="0,0,0,16"/>

        <Border Style="{StaticResource Card}" Margin="0,0,0,14"><StackPanel>
          <TextBlock x:Name="LblBase" Style="{StaticResource Title}"/>
          <DockPanel Margin="0,10,0,0">
            <Button x:Name="BtnBase" DockPanel.Dock="Right" Margin="10,0,0,0"/>
            <TextBox x:Name="TxtBase" FontFamily="{StaticResource F.Mono}"/>
          </DockPanel>
          <TextBlock x:Name="HintBase" Style="{StaticResource Muted}" FontSize="12" Margin="0,6,0,0"/>
        </StackPanel></Border>

        <Border Style="{StaticResource Card}" Margin="0,0,0,14"><StackPanel>
          <TextBlock x:Name="LblWhat" Style="{StaticResource Title}" Margin="0,0,0,12"/>
          <WrapPanel x:Name="Tiles"/>
        </StackPanel></Border>

        <Border Style="{StaticResource Card}"><StackPanel>
          <TextBlock x:Name="LblOrg" Style="{StaticResource Title}" Margin="0,0,0,12"/>
          <ContentControl x:Name="OrgHost"/>
        </StackPanel></Border>
      </StackPanel>
    </ScrollViewer>
  </DockPanel>
</Window>
'@
    $w = Parse-Xaml $xaml
    $w.Height = (Get-FitHeight 900)
    Initialize-Window $w $script:MainWin
    $w.Title = (T 'qs.title')
    $q = @{ Window = $w }
    foreach ($n in "Intro", "LblBase", "BtnBase", "TxtBase", "HintBase", "LblWhat", "Tiles", "LblOrg", "OrgHost", "BtnCancel", "BtnCreate") { $q[$n] = $w.FindName($n) }
    $script:QS = $q

    $q.Intro.Text = (T 'qs.intro')
    $q.LblBase.Text = (T 'qs.base'); $q.HintBase.Text = (T 'qs.base_hint')
    $q.TxtBase.Text = (Join-Path ([Environment]::GetFolderPath("MyPictures")) "Phone")
    Set-IconLabel $q.BtnBase "ED25" (T 'editor.browse')
    $q.LblWhat.Text = (T 'qs.what'); $q.LblOrg.Text = (T 'qs.org')
    $q.BtnCancel.Content = (T 'btn.cancel'); $q.BtnCreate.Content = (T 'qs.create')

    # one tile per preset
    $q.Presets = @(Get-Presets)
    $q.TileList = New-Object System.Collections.ArrayList
    foreach ($p in $q.Presets) {
        $tile = New-Object System.Windows.Controls.Primitives.ToggleButton
        $tile.Style = $script:App.FindResource("Tile"); $tile.Width = 240
        $tile.Margin = New-Object System.Windows.Thickness(0, 0, 10, 10)
        $tile.HorizontalContentAlignment = "Stretch"
        $tile.IsChecked = [bool]$p.Default
        $g = New-Object System.Windows.Controls.Grid
        $c1 = New-Object System.Windows.Controls.ColumnDefinition; $c1.Width = [System.Windows.GridLength]::Auto
        $c2 = New-Object System.Windows.Controls.ColumnDefinition; $c2.Width = New-Object System.Windows.GridLength(1, "Star")
        [void]$g.ColumnDefinitions.Add($c1); [void]$g.ColumnDefinitions.Add($c2)
        $ib = New-Object System.Windows.Controls.Border
        $ib.Width = 36; $ib.Height = 36; $ib.CornerRadius = New-Object System.Windows.CornerRadius(6); $ib.Margin = New-Object System.Windows.Thickness(0, 0, 12, 0)
        $ib.SetResourceReference([System.Windows.Controls.Border]::BackgroundProperty, "B.SurfaceAlt")
        $ib.Child = (New-Icon (Get-RuleIconCode $p) 17 "B.AccentInk")
        [void]$g.Children.Add($ib)
        $sp = New-Object System.Windows.Controls.StackPanel; $sp.VerticalAlignment = "Center"
        [System.Windows.Controls.Grid]::SetColumn($sp, 1)
        $nm = New-Object System.Windows.Controls.TextBlock; $nm.Text = (T "preset.$($p.Key)"); $nm.FontWeight = "SemiBold"; $nm.TextWrapping = "Wrap"
        $ph = New-Object System.Windows.Controls.TextBlock; $ph.Text = $p.Phone; $ph.FontSize = 10.5; $ph.TextTrimming = "CharacterEllipsis"
        $ph.FontFamily = $script:App.FindResource("F.Mono")
        $ph.SetResourceReference([System.Windows.Controls.TextBlock]::ForegroundProperty, "B.Muted")
        [void]$sp.Children.Add($nm); [void]$sp.Children.Add($ph)
        [void]$g.Children.Add($sp)
        $tile.Content = $g
        $tile.ToolTip = $p.Phone
        [void]$q.TileList.Add($tile)
        [void]$q.Tiles.Children.Add($tile)
    }
    $q.Org = New-OrgCards "flat" "org-quick"
    $q.OrgHost.Content = $q.Org.Root

    $q.BtnBase.Add_Click({
        $p = Select-Folder (T 'editor.browse_dest') $script:QS.TxtBase.Text
        if ($p) { $script:QS.TxtBase.Text = $p }
    })
    $script:QuickResult = $null
    $q.BtnCreate.Add_Click({
        $qs = $script:QS
        $base = $qs.TxtBase.Text.Trim()
        if (-not $base) { [void](Show-Message (T 'editor.err_dest') "warn"); return }
        $org = [string](Get-CheckedTag $qs.Org.Radios)
        $out = @()
        for ($i = 0; $i -lt $qs.Presets.Count; $i++) {
            if (-not $qs.TileList[$i].IsChecked) { continue }
            $p = $qs.Presets[$i]
            $rule = New-Rule (T "preset.$($p.Key)") $p.Phone (Compress-Path (Join-Path $base (Get-SafeFolderName $p.Dest)))
            $rule.includeSubfolders = [bool]$p.Sub
            $rule.organization = $org
            if ($org -eq "mirror") { $rule.includeSubfolders = $true }
            $out += $rule
        }
        if ($out.Count -eq 0) { [void](Show-Message (T 'qs.err_none') "warn"); return }
        $script:QuickResult = $out
        $qs.Window.DialogResult = $true
    })

    [void]$w.ShowDialog()
    return $script:QuickResult
}
