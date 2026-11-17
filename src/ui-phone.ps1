# ui-phone.ps1 - browse the phone's folders (WPF): a breadcrumb and a list; folders are read on demand in the background

$script:PB = @{}

# Called on the UI thread when a background listing has finished
function Complete-PhoneListing($res, $err, $token) {
    $pb = $script:PB
    if ($token -ne $pb.Token) { return }          # a newer navigation replaced this one
    $pb.Busy = $true
    $pb.List.Items.Clear()
    $pb.Spinner.Visibility = "Collapsed"
    $r = if ($res -and $res.Count -gt 0) { $res[0] } else { $null }
    if ($err -or -not $r -or -not $r.Ok) {
        $pb.Status.Text = $(if ($r -and $r.Error -eq "nophone") { T 'pb.err_nophone' } elseif ($r) { T 'pb.err' $r.Error } else { T 'pb.err' $err })
        $pb.Busy = $false; return
    }
    $folders = @($r.Folders)
    if (-not $pb.Storage -and $folders.Count -eq 1) {      # one storage: go straight in
        $pb.Storage = [string]$folders[0]; $pb.Busy = $false; Use-PhoneInitialPath; Load-PhoneFolder; return
    }
    foreach ($name in $folders) {
        $it = New-Object System.Windows.Controls.ListBoxItem
        $sp = New-Object System.Windows.Controls.StackPanel; $sp.Orientation = "Horizontal"
        $ic = New-Icon $(if ($pb.Storage) { "ED25" } else { "E8EA" }) 16 "B.AccentInk"; $ic.Margin = New-Object System.Windows.Thickness(0, 0, 12, 0)
        [void]$sp.Children.Add($ic)
        $tb = New-Object System.Windows.Controls.TextBlock; $tb.Text = [string]$name; $tb.VerticalAlignment = "Center"
        [void]$sp.Children.Add($tb)
        $it.Content = $sp; $it.Tag = [string]$name
        [void]$pb.List.Items.Add($it)
    }
    $pb.Status.Text = $(if ($folders.Count -eq 0) { T 'pb.empty' } else { "" })
    $pb.Busy = $false
    Update-PhoneCrumbs
}

# Once a storage is chosen, start inside the requested folder (only the first time)
function Use-PhoneInitialPath {
    $pb = $script:PB
    if (-not $pb.Initial) { return }
    foreach ($s in ($pb.Initial -split '\\')) { if ($s) { [void]$pb.Segments.Add($s) } }
    $pb.Initial = ""
}

function Load-PhoneFolder {
    $pb = $script:PB
    $pb.Token++
    $pb.Busy = $true
    $pb.List.Items.Clear()
    $pb.Status.Text = (T 'pb.loading')
    $pb.Spinner.Visibility = "Visible"
    Update-PhoneCrumbs
    $path = ($pb.Segments -join "\")
    [void](Start-AsyncJob $script:ListPhoneFoldersScript @($pb.Phone, [string]$pb.Storage, $path) ${function:Complete-PhoneListing} $pb.Token)
}

# breadcrumb: phone > storage > folder > folder ...
function Update-PhoneCrumbs {
    $pb = $script:PB
    $pb.Crumbs.Children.Clear()
    $parts = @(@{ Text = $pb.Phone; Level = -2 })
    if ($pb.Storage) { $parts += @{ Text = $pb.Storage; Level = -1 } }
    for ($i = 0; $i -lt $pb.Segments.Count; $i++) { $parts += @{ Text = [string]$pb.Segments[$i]; Level = $i } }
    for ($i = 0; $i -lt $parts.Count; $i++) {
        if ($i -gt 0) { $sep = New-Icon "E76C" 10 "B.Muted"; $sep.Margin = New-Object System.Windows.Thickness(2, 0, 2, 0); [void]$pb.Crumbs.Children.Add($sep) }
        $b = New-Object System.Windows.Controls.Button
        $b.Style = $script:App.FindResource("IconButton"); $b.Width = [double]::NaN; $b.Height = 28
        $b.Padding = New-Object System.Windows.Thickness(8, 0, 8, 0)
        $b.Content = $parts[$i].Text; $b.Tag = $parts[$i].Level
        $b.Foreground = $(if ($i -eq $parts.Count - 1) { $script:App.FindResource("B.Text") } else { $script:App.FindResource("B.Muted") })
        $b.Add_Click({ param($s, $e) Go-PhoneLevel ([int]$s.Tag) })
        [void]$pb.Crumbs.Children.Add($b)
    }
    $pb.BtnOk.IsEnabled = ($pb.Segments.Count -gt 0)
}

function Go-PhoneLevel([int]$level) {
    $pb = $script:PB
    if ($level -eq -2) { $pb.Storage = ""; $pb.Segments.Clear() }
    elseif ($level -eq -1) { $pb.Segments.Clear() }
    else { while ($pb.Segments.Count -gt ($level + 1)) { $pb.Segments.RemoveAt($pb.Segments.Count - 1) } }
    Load-PhoneFolder
}

# Returns the selected path inside the phone's storage (e.g. "DCIM\Camera") or $null.
function Show-PhoneBrowser($phoneName, $initialPath, $owner = $null) {
    $xaml = @'
<Window Width="620" Height="640" ResizeMode="NoResize" ShowInTaskbar="False">
  <DockPanel Margin="0">
    <Border DockPanel.Dock="Bottom" Background="{DynamicResource B.Surface}" BorderBrush="{DynamicResource B.Border}" BorderThickness="0,1,0,0" Padding="22,14">
      <DockPanel>
        <StackPanel DockPanel.Dock="Right" Orientation="Horizontal">
          <Button x:Name="BtnCancel" IsCancel="True" MinWidth="90" Margin="0,0,10,0"/>
          <Button x:Name="BtnOk" Style="{StaticResource PrimaryButton}" IsEnabled="False"/>
        </StackPanel>
        <TextBlock x:Name="Status" Style="{StaticResource Muted}" VerticalAlignment="Center" Margin="0,0,12,0"/>
      </DockPanel>
    </Border>
    <StackPanel DockPanel.Dock="Top" Margin="22,20,22,10">
      <TextBlock x:Name="Info" Style="{StaticResource Muted}"/>
      <Border Style="{StaticResource Card}" Padding="8,6" Margin="0,12,0,0">
        <WrapPanel x:Name="Crumbs" VerticalAlignment="Center"/>
      </Border>
      <ProgressBar x:Name="Spinner" IsIndeterminate="True" Height="3" Margin="0,8,0,0" Visibility="Collapsed" BorderThickness="0"
                   Foreground="{DynamicResource B.Accent}" Background="{DynamicResource B.Border}"/>
    </StackPanel>
    <Border Style="{StaticResource Card}" Margin="22,0,22,16" Padding="6">
      <ListBox x:Name="List" Style="{StaticResource PlainList}"/>
    </Border>
  </DockPanel>
</Window>
'@
    $w = Parse-Xaml $xaml
    Initialize-Window $w $(if ($owner) { $owner } else { $script:MainWin })
    $w.Title = (T 'pb.title')
    $pb = @{ Window = $w; Phone = $phoneName; Storage = ""; Segments = (New-Object System.Collections.ArrayList); Token = 0; Busy = $false; Result = $null; Initial = ([string]$initialPath).Trim('\', '/') }
    foreach ($n in "BtnCancel", "BtnOk", "Status", "Info", "Crumbs", "Spinner", "List") { $pb[$n] = $w.FindName($n) }
    $script:PB = $pb
    $pb.Info.Text = (T 'pb.info')
    $pb.BtnCancel.Content = (T 'btn.cancel')
    Set-IconLabel $pb.BtnOk "E73E" (T 'btn.select_here')

    $pb.List.Add_SelectionChanged({
        $p = $script:PB
        if ($p.Busy) { return }
        $it = $p.List.SelectedItem
        if (-not $it) { return }
        if (-not $p.Storage) { $p.Storage = [string]$it.Tag; Use-PhoneInitialPath } else { [void]$p.Segments.Add([string]$it.Tag) }
        Load-PhoneFolder
    })
    $pb.BtnOk.Add_Click({
        $p = $script:PB
        if ($p.Segments.Count -gt 0) { $p.Result = ($p.Segments -join "\"); $p.Window.DialogResult = $true }
    })

    Load-PhoneFolder
    [void]$w.ShowDialog()
    return $script:PB.Result
}
