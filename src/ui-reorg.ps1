# ui-reorg.ps1 - "Tidy up existing files": move the files already copied into the structure a rule now uses.
# Shows what would happen first; nothing is deleted or overwritten; the phone is not involved.

$script:RG = @{}

function New-CountRow([string]$glyph, [string]$brush, [string]$text) {
    $sp = New-Object System.Windows.Controls.StackPanel
    $sp.Orientation = "Horizontal"; $sp.Margin = New-Object System.Windows.Thickness(0, 3, 0, 3)
    $ic = New-Icon $glyph 15 $brush; $ic.Margin = New-Object System.Windows.Thickness(0, 0, 10, 0)
    [void]$sp.Children.Add($ic)
    $tb = New-Object System.Windows.Controls.TextBlock; $tb.Text = $text; $tb.VerticalAlignment = "Center"
    [void]$sp.Children.Add($tb)
    return $sp
}

function Step-Reorganize {
    $rg = $script:RG
    $batch = 30
    while ($batch -gt 0 -and $rg.Index -lt $rg.Items.Count) {
        if (Move-PlanItem $rg.Items[$rg.Index]) { $rg.Moved++ } else { $rg.Failed++ }
        $rg.Index++; $batch--
    }
    Set-FilmProgress $rg.Strip ([double]$rg.Index / [double]$rg.Items.Count)
    $rg.Status.Text = (T 'reorg.progress' $rg.Index $rg.Items.Count)
    if ($rg.Index -ge $rg.Items.Count) {
        $rg.Timer.Stop()
        Remove-EmptyDateFolders $rg.Plan.Source
        Remove-EmptyDateFolders $rg.Plan.Dest
        $rg.Status.Text = $(if ($rg.Failed -gt 0) { (T 'reorg.done_failed' $rg.Moved $rg.Failed) } else { (T 'reorg.done' $rg.Moved) })
        $rg.BtnCancel.Content = (T 'btn.close'); $rg.BtnCancel.IsEnabled = $true
        $rg.Running = $false
    }
}

# Returns $true if any file was moved. $sourceRoot = where the files are now (old destination); empty = the rule's destination.
function Show-Reorganize($rule, [string]$sourceRoot = "") {
    $plan = New-ReorganizePlan $rule $sourceRoot
    if ($plan.Unsupported) { [void](Show-Message (T 'reorg.unsupported')); return $false }
    if ($plan.Move -eq 0) {
        $txt = (T 'reorg.nothing')
        if ($plan.Conflict -gt 0) { $txt += "`n`n" + (T 'reorg.conflict' $plan.Conflict) }
        [void](Show-Message $txt); return $false
    }

    $xaml = @'
<Window Width="680" ResizeMode="NoResize" ShowInTaskbar="False" SizeToContent="Height">
  <StackPanel>
    <StackPanel Margin="26,22,26,8">
      <TextBlock x:Name="Head" Style="{StaticResource Display}" FontSize="22"/>
      <TextBlock x:Name="RuleName" Style="{StaticResource Muted}" Margin="0,2,0,0"/>
      <TextBlock x:Name="Intro" Style="{StaticResource Muted}" Margin="0,12,0,0"/>
      <Border Style="{StaticResource Card}" Margin="0,16,0,0" Padding="16,12">
        <StackPanel x:Name="Counts"/>
      </Border>
      <TextBlock x:Name="ExHead" Style="{StaticResource Muted}" Margin="0,16,0,6"/>
      <Border Style="{StaticResource Card}" Padding="8">
        <ListBox x:Name="Examples" Style="{StaticResource PlainList}" MaxHeight="150" IsHitTestVisible="False"/>
      </Border>
      <ContentControl x:Name="FilmHost" Margin="0,16,0,0" Visibility="Collapsed"/>
      <TextBlock x:Name="Status" Style="{StaticResource Title}" Margin="0,12,0,0" FontSize="14"/>
    </StackPanel>
    <Border Background="{DynamicResource B.Surface}" BorderBrush="{DynamicResource B.Border}" BorderThickness="0,1,0,0" Padding="26,14" Margin="0,16,0,0">
      <StackPanel Orientation="Horizontal" HorizontalAlignment="Right">
        <Button x:Name="BtnCancel" IsCancel="True" MinWidth="100" Margin="0,0,10,0"/>
        <Button x:Name="BtnMove" Style="{StaticResource PrimaryButton}" MinWidth="140"/>
      </StackPanel>
    </Border>
  </StackPanel>
</Window>
'@
    $w = Parse-Xaml $xaml
    Initialize-Window $w $script:MainWin
    $w.Title = (T 'reorg.title')
    $rg = @{ Window = $w; Plan = $plan; Items = $plan.Items; Index = 0; Moved = 0; Failed = 0; Running = $false }
    foreach ($n in "Head", "RuleName", "Intro", "Counts", "ExHead", "Examples", "FilmHost", "Status", "BtnCancel", "BtnMove") { $rg[$n] = $w.FindName($n) }
    $script:RG = $rg

    $rg.Head.Text = (T 'reorg.title')
    $rg.RuleName.Text = (T 'reorg.rule' $rule.name)
    $rg.Intro.Text = (T 'reorg.intro')
    [void]$rg.Counts.Children.Add((New-CountRow "E8DE" "B.AccentInk" (T 'reorg.will_move' $plan.Move)))
    [void]$rg.Counts.Children.Add((New-CountRow "E73E" "B.Success" (T 'reorg.in_place' $plan.InPlace)))
    if ($plan.Conflict -gt 0) { [void]$rg.Counts.Children.Add((New-CountRow "E7BA" "B.Warn" (T 'reorg.conflict' $plan.Conflict))) }
    $rg.ExHead.Text = (T 'reorg.examples')
    $shown = 0
    foreach ($it in $plan.Items) {
        if ($shown -ge 8) { break }
        $a = $it.From.Substring([Math]::Min($it.From.Length, $plan.Source.Length)).TrimStart('\')
        $b = $it.To.Substring([Math]::Min($it.To.Length, $plan.Dest.Length)).TrimStart('\')
        $li = New-Object System.Windows.Controls.ListBoxItem
        $tb = New-Object System.Windows.Controls.TextBlock; $tb.FontFamily = $script:App.FindResource("F.Mono"); $tb.FontSize = 12
        $tb.Text = ("{0}   {1}   {2}" -f $a, [char]0x2192, $b); $tb.TextTrimming = "CharacterEllipsis"
        $li.Content = $tb; $li.Padding = New-Object System.Windows.Thickness(8, 3, 8, 3)
        [void]$rg.Examples.Items.Add($li); $shown++
    }
    $rg.Strip = New-FilmStrip; $rg.FilmHost.Content = $rg.Strip.Root
    $rg.BtnCancel.Content = (T 'btn.cancel')
    Set-IconLabel $rg.BtnMove "E8DE" (T 'reorg.move_btn')

    $rg.Timer = New-Object System.Windows.Threading.DispatcherTimer
    $rg.Timer.Interval = [TimeSpan]::FromMilliseconds(15)
    $rg.Timer.Add_Tick({ Step-Reorganize })
    $rg.BtnMove.Add_Click({
        $r = $script:RG
        $r.BtnMove.Visibility = "Collapsed"; $r.FilmHost.Visibility = "Visible"; $r.BtnCancel.IsEnabled = $false
        $r.Running = $true; $r.Timer.Start()
    })
    $w.Add_Closing({ if ($script:RG.Timer) { $script:RG.Timer.Stop() } })

    [void]$w.ShowDialog()
    return ($script:RG.Moved -gt 0)
}
