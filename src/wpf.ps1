# wpf.ps1 - WPF helpers: application, theme (light/dark), icons, logo, XAML snippets, dialogs, film-strip progress.
# WPF ships with Windows PowerShell 5.1 (run it with -Sta): no framework to install.

Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase, System.Xaml, System.Windows.Forms

$script:App         = $null
$script:PaletteDict = $null
$script:ThemeMode   = "light"
$script:MainWin     = $null
$script:IconFont    = New-Object System.Windows.Media.FontFamily("Segoe MDL2 Assets")
$script:AppIconPath = $null

Add-Type -Namespace SF -Name Dwm -MemberDefinition @'
[System.Runtime.InteropServices.DllImport("dwmapi.dll")]
public static extern int DwmSetWindowAttribute(System.IntPtr hwnd, int attr, ref int value, int size);
'@

function Initialize-Wpf {
    if (-not [System.Windows.Application]::Current) {
        $script:App = New-Object System.Windows.Application
        $script:App.ShutdownMode = "OnExplicitShutdown"
    } else { $script:App = [System.Windows.Application]::Current }
    $stream = [IO.File]::OpenRead((Join-Path $script:AppRoot "ui\styles.xaml"))
    try { $styles = [Windows.Markup.XamlReader]::Load($stream) } finally { $stream.Dispose() }
    [void]$script:App.Resources.MergedDictionaries.Add($styles)
    $ico = Join-Path $script:AppRoot "assets\icon.png"
    if (Test-Path -LiteralPath $ico) { $script:AppIconPath = $ico }
}

function Test-SystemDark {
    try { return ((Get-ItemPropertyValue "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" -Name AppsUseLightTheme -ErrorAction Stop) -eq 0) }
    catch { return $false }
}

# mode: light | dark | auto
function Set-Theme($mode) {
    $eff = $mode
    if ($mode -ne "light" -and $mode -ne "dark") { $eff = if (Test-SystemDark) { "dark" } else { "light" } }
    $stream = [IO.File]::OpenRead((Join-Path $script:AppRoot "ui\palette.$eff.xaml"))
    try { $dict = [Windows.Markup.XamlReader]::Load($stream) } finally { $stream.Dispose() }
    $md = $script:App.Resources.MergedDictionaries
    if ($script:PaletteDict) { [void]$md.Remove($script:PaletteDict) }
    $md.Insert(0, $dict)
    $script:PaletteDict = $dict
    $script:ThemeMode = $eff
    foreach ($w in $script:App.Windows) { Set-TitleBarTheme $w }
}

# dark title bar on Windows 10 2004+ / 11
function Set-TitleBarTheme($window) {
    try {
        $h = (New-Object System.Windows.Interop.WindowInteropHelper($window)).Handle
        if ($h -eq [IntPtr]::Zero) { return }
        $v = if ($script:ThemeMode -eq "dark") { 1 } else { 0 }
        [void][SF.Dwm]::DwmSetWindowAttribute($h, 20, [ref]$v, 4)
    } catch {}
}

# Parses a XAML snippet; namespaces are added for you.
function Parse-Xaml([string]$xaml) {
    $ns = 'xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"'
    $rx = New-Object System.Text.RegularExpressions.Regex('^\s*<(\w+)')
    return [Windows.Markup.XamlReader]::Parse($rx.Replace($xaml, ('<$1 ' + $ns), 1))
}

function Esc([string]$s) { [System.Security.SecurityElement]::Escape($s) }

# Segoe MDL2 Assets glyph. $code = hex such as "E8B9"; $brushKey = palette key such as "B.Muted"
function New-Icon([string]$code, [double]$size = 16, [string]$brushKey = "") {
    $t = New-Object System.Windows.Controls.TextBlock
    $t.Text = [string][char][Convert]::ToInt32($code, 16)
    $t.FontFamily = $script:IconFont
    $t.FontSize = $size
    $t.HorizontalAlignment = "Center"; $t.VerticalAlignment = "Center"
    if ($brushKey) { $t.SetResourceReference([System.Windows.Controls.TextBlock]::ForegroundProperty, $brushKey) }
    return $t
}

# accessible name (screen readers) for controls that only show an icon; also used as tooltip
function Set-A11yName($element, [string]$name) {
    [System.Windows.Automation.AutomationProperties]::SetName($element, $name)
    $element.ToolTip = $name
}

# icon + text, for buttons
function New-IconLabel([string]$code, [string]$text, [double]$size = 14) {
    $sp = New-Object System.Windows.Controls.StackPanel
    $sp.Orientation = "Horizontal"
    $ic = New-Icon $code $size
    $ic.Margin = New-Object System.Windows.Thickness(0, 0, 8, 0)
    [void]$sp.Children.Add($ic)
    $tb = New-Object System.Windows.Controls.TextBlock; $tb.Text = $text; $tb.VerticalAlignment = "Center"
    [void]$sp.Children.Add($tb)
    return $sp
}

# button/toggle content = icon + text; the text is also its accessible name
function Set-IconLabel($control, [string]$code, [string]$text, [double]$size = 14) {
    $control.Content = (New-IconLabel $code $text $size)
    [System.Windows.Automation.AutomationProperties]::SetName($control, $text)
}

# small read-only pill (type, organization...). $kind: neutral | accent
function New-Tag([string]$text, [string]$iconCode = "", [string]$kind = "neutral") {
    $b = New-Object System.Windows.Controls.Border
    $b.CornerRadius = New-Object System.Windows.CornerRadius(11)
    $b.Padding = New-Object System.Windows.Thickness(9, 2, 9, 3)
    $b.Margin = New-Object System.Windows.Thickness(0, 0, 6, 0)
    $b.BorderThickness = New-Object System.Windows.Thickness(1)
    $b.SetResourceReference([System.Windows.Controls.Border]::BackgroundProperty, $(if ($kind -eq "accent") { "B.AccentSoft" } else { "B.SurfaceAlt" }))
    $b.SetResourceReference([System.Windows.Controls.Border]::BorderBrushProperty, $(if ($kind -eq "accent") { "B.Accent" } else { "B.Border" }))
    $sp = New-Object System.Windows.Controls.StackPanel; $sp.Orientation = "Horizontal"
    if ($iconCode) { $ic = New-Icon $iconCode 11 "B.Muted"; $ic.Margin = New-Object System.Windows.Thickness(0, 0, 5, 0); [void]$sp.Children.Add($ic) }
    $tb = New-Object System.Windows.Controls.TextBlock; $tb.Text = $text; $tb.FontSize = 12
    $tb.SetResourceReference([System.Windows.Controls.TextBlock]::ForegroundProperty, $(if ($kind -eq "accent") { "B.Text" } else { "B.Muted" }))
    [void]$sp.Children.Add($tb)
    $b.Child = $sp
    return $b
}

# Icon for a rule, from what its phone folder looks like
function Get-RuleIconCode($rule) {
    $p = $(if ($rule.phoneFolder) { [string]$rule.phoneFolder } else { [string]$rule.Phone }).ToLower()   # rule or preset
    if ($p -match 'whatsapp')                 { return "E8BD" }   # chat
    if ($p -match 'dcim|camera')              { return "E722" }   # camera
    if ($p -match 'screenshot')               { return "E7F4" }   # screen
    if ($p -match 'download')                 { return "E896" }   # download
    if ($p -match 'movie|video')              { return "E714" }   # video
    if ($p -match 'music|audio|record|sound') { return "E8D6" }   # music note
    if ($p -match 'document')                 { return "E8A5" }   # document
    if ($p -match 'picture|photo|image')      { return "EB9F" }   # photo
    return "ED25"                                                  # folder
}

function Get-SafeFolderName($s) {
    $bad = [IO.Path]::GetInvalidFileNameChars()
    return (($s.ToCharArray() | ForEach-Object { if ($bad -contains $_) { '_' } else { $_ } }) -join '').Trim()
}

# ---------------------------------------------------------------- logo (a film frame with a sun and a hill)
function New-Logo([double]$size = 44) {
    $holes = ""
    foreach ($x in 6, 13, 20, 27, 34) { $holes += "<Rectangle Canvas.Left='$x' Canvas.Top='5' Width='4' Height='4' RadiusX='1' RadiusY='1' Fill='#E8EBEE' Opacity='0.85'/>"
                                         $holes += "<Rectangle Canvas.Left='$x' Canvas.Top='35' Width='4' Height='4' RadiusX='1' RadiusY='1' Fill='#E8EBEE' Opacity='0.85'/>" }
    return (Parse-Xaml ("<Viewbox Width='$size' Height='$size'><Canvas Width='44' Height='44'>" +
        "<Rectangle Width='44' Height='44' RadiusX='10' RadiusY='10' Fill='#1A1C20'/>" + $holes +
        "<Rectangle Canvas.Left='7' Canvas.Top='12' Width='30' Height='20' RadiusX='3' RadiusY='3' Fill='#F2B01E'/>" +
        "<Ellipse Canvas.Left='13' Canvas.Top='16' Width='6' Height='6' Fill='#1A1C20'/>" +
        "<Path Data='M 10,30 L 19,21 L 25,27 L 29,23 L 34,30 Z' Fill='#1A1C20'/>" +
        "</Canvas></Viewbox>"))
}

# ---------------------------------------------------------------- windows & dialogs
# Sets the common look of a window created from XAML
function Initialize-Window($win, $owner = $null) {
    if ($owner) { $win.Owner = $owner; $win.WindowStartupLocation = "CenterOwner" } else { $win.WindowStartupLocation = "CenterScreen" }
    if ($script:AppIconPath) {
        try { $win.Icon = [System.Windows.Media.Imaging.BitmapFrame]::Create((New-Object Uri($script:AppIconPath))) } catch {}
    }
    $win.Add_SourceInitialized({ param($s, $e) Set-TitleBarTheme $s })
}

# Window height that fits the screen
function Get-FitHeight([double]$wanted) { [Math]::Min($wanted, [System.Windows.SystemParameters]::WorkArea.Height - 40) }

# kind: info | warn | error | question.  buttons: OK | YesNo.  Returns "OK", "Yes" or "No".
function Show-Message([string]$text, [string]$kind = "info", [string]$buttons = "OK") {
    $g = switch ($kind) { "warn" { @("E7BA", "B.WarnSoft", "B.Warn") } "error" { @("E783", "B.DangerSoft", "B.Danger") }
                          "question" { @("E897", "B.AccentSoft", "B.AccentInk") } default { @("E946", "B.AccentSoft", "B.AccentInk") } }
    $xaml = @'
<Window Title="" Width="460" SizeToContent="Height" ResizeMode="NoResize" ShowInTaskbar="False">
  <Grid Margin="24">
    <Grid.RowDefinitions><RowDefinition Height="Auto"/><RowDefinition Height="Auto"/></Grid.RowDefinitions>
    <Grid Grid.Row="0">
      <Grid.ColumnDefinitions><ColumnDefinition Width="Auto"/><ColumnDefinition Width="*"/></Grid.ColumnDefinitions>
      <Border x:Name="IconBox" Width="44" Height="44" CornerRadius="22" VerticalAlignment="Top" Margin="0,0,16,0"/>
      <TextBlock x:Name="Msg" Grid.Column="1" TextWrapping="Wrap" VerticalAlignment="Center" LineHeight="20"/>
    </Grid>
    <StackPanel x:Name="Buttons" Grid.Row="1" Orientation="Horizontal" HorizontalAlignment="Right" Margin="0,22,0,0"/>
  </Grid>
</Window>
'@
    $w = Parse-Xaml $xaml
    Initialize-Window $w $(if ($script:MainWin -and $script:MainWin.IsVisible) { $script:MainWin } else { $null })
    $w.Title = (T 'app.title')
    $w.FindName("Msg").Text = $text
    $box = $w.FindName("IconBox"); $box.SetResourceReference([System.Windows.Controls.Border]::BackgroundProperty, $g[1])
    $icon = New-Icon $g[0] 20 $g[2]; $box.Child = $icon
    $script:MsgResult = "OK"
    $bar = $w.FindName("Buttons")
    $addBtn = {
        param($label, $result, $primary)
        $b = New-Object System.Windows.Controls.Button; $b.Content = $label; $b.MinWidth = 90
        $b.Margin = New-Object System.Windows.Thickness(8, 0, 0, 0)
        if ($primary) { $b.Style = $script:App.FindResource("PrimaryButton"); $b.IsDefault = $true; $b.FontSize = 13 }
        $b.Tag = $result
        $b.Add_Click({ param($s, $e) $script:MsgResult = $s.Tag; $script:MsgWin.Close() })
        [void]$bar.Children.Add($b)
    }
    $script:MsgWin = $w
    if ($buttons -eq "YesNo") { & $addBtn (T 'btn.no') "No" $false; & $addBtn (T 'btn.yes') "Yes" $true }
    else { & $addBtn (T 'btn.ok') "OK" $true }
    [void]$w.ShowDialog()
    return $script:MsgResult
}

function Select-Folder([string]$description, [string]$initial = "") {
    $fb = New-Object System.Windows.Forms.FolderBrowserDialog
    $fb.Description = $description
    $init = Expand-Path $initial
    if ($init -and (Test-Path -LiteralPath $init)) { $fb.SelectedPath = $init }
    if ($fb.ShowDialog() -eq "OK") { return $fb.SelectedPath }
    return $null
}

# ---------------------------------------------------------------- PNG / ICO export (used by tools\make-icon.ps1)
function Save-VisualPng($element, [int]$px, [string]$path) {
    $element.Measure((New-Object System.Windows.Size($px, $px)))
    $element.Arrange((New-Object System.Windows.Rect(0, 0, $px, $px)))
    $element.UpdateLayout()
    $rtb = New-Object System.Windows.Media.Imaging.RenderTargetBitmap($px, $px, 96, 96, [System.Windows.Media.PixelFormats]::Pbgra32)
    $rtb.Render($element)
    $enc = New-Object System.Windows.Media.Imaging.PngBitmapEncoder
    $enc.Frames.Add([System.Windows.Media.Imaging.BitmapFrame]::Create($rtb))
    $fs = [IO.File]::Create($path); try { $enc.Save($fs) } finally { $fs.Dispose() }
}

# ---------------------------------------------------------------- film strip progress bar
# One strip of film: perforations top and bottom, one frame per step.
#   Set-FilmProgress $strip 0..1   frames light up from the left
#   Set-FilmBusy $strip $true      unknown length: the strip scrolls
function New-FilmStrip {
    $frame = '<GeometryDrawing Brush="{DynamicResource %FRAME%}"><GeometryDrawing.Geometry><RectangleGeometry Rect="2,13,24,20" RadiusX="2" RadiusY="2"/></GeometryDrawing.Geometry></GeometryDrawing>'
    $holes = '<GeometryDrawing Brush="{DynamicResource B.FilmHole}"><GeometryDrawing.Geometry><GeometryGroup>' +
             '<RectangleGeometry Rect="4,4,6,6" RadiusX="1.5" RadiusY="1.5"/><RectangleGeometry Rect="18,4,6,6" RadiusX="1.5" RadiusY="1.5"/>' +
             '<RectangleGeometry Rect="4,36,6,6" RadiusX="1.5" RadiusY="1.5"/><RectangleGeometry Rect="18,36,6,6" RadiusX="1.5" RadiusY="1.5"/>' +
             '</GeometryGroup></GeometryDrawing.Geometry></GeometryDrawing>'
    $brush = '<DrawingBrush x:Name="%NAME%" TileMode="Tile" ViewportUnits="Absolute" Viewport="0,0,28,46" ViewboxUnits="Absolute" Viewbox="0,0,28,46"><DrawingBrush.Drawing><DrawingGroup>%FRAME%' + $holes + '</DrawingGroup></DrawingBrush.Drawing></DrawingBrush>'
    $baseBrush = $brush.Replace('%NAME%', 'BaseBrush').Replace('%FRAME%', $frame.Replace('%FRAME%', 'B.FilmFrame'))
    $litBrush  = $brush.Replace('%NAME%', 'LitBrush').Replace('%FRAME%', $frame.Replace('%FRAME%', 'B.Accent'))
    $xaml = '<Border Height="46" CornerRadius="6" ClipToBounds="True" Background="{DynamicResource B.Film}"><Grid>' +
            '<Rectangle x:Name="BaseFilm"><Rectangle.Fill>' + $baseBrush + '</Rectangle.Fill></Rectangle>' +
            '<Rectangle x:Name="LitFilm" HorizontalAlignment="Left" Width="0"><Rectangle.Fill>' + $litBrush + '</Rectangle.Fill></Rectangle>' +
            '</Grid></Border>'
    $root = Parse-Xaml $xaml
    return [pscustomobject]@{ Root = $root; Lit = $root.FindName("LitFilm"); LitBrush = $root.FindName("LitBrush"); Busy = $false; Fraction = 0.0 }
}

# frames light up in whole steps of 28 px so the lit part always ends on a frame
function Set-FilmProgress($strip, [double]$fraction) {
    Set-FilmBusy $strip $false
    $f = [Math]::Max(0.0, [Math]::Min(1.0, $fraction))
    $strip.Fraction = $f
    $w = $strip.Root.ActualWidth
    if ($w -le 0) { $w = 700.0 }
    $strip.Lit.Opacity = 1.0
    $strip.Lit.Width = $(if ($f -ge 1.0) { $w } else { [Math]::Floor(($w * $f) / 28.0) * 28.0 })
}

function Set-FilmBusy($strip, [bool]$busy) {
    if ($busy -eq $strip.Busy) { return }
    $strip.Busy = $busy
    if ($busy) {
        $tt = New-Object System.Windows.Media.TranslateTransform
        $strip.Lit.Width = [double]::NaN; $strip.Lit.HorizontalAlignment = "Stretch"; $strip.Lit.Opacity = 0.35
        $strip.LitBrush.Transform = $tt
        $anim = New-Object System.Windows.Media.Animation.DoubleAnimation(0.0, -28.0, (New-Object System.Windows.Duration([TimeSpan]::FromMilliseconds(900))))
        $anim.RepeatBehavior = [System.Windows.Media.Animation.RepeatBehavior]::Forever
        $tt.BeginAnimation([System.Windows.Media.TranslateTransform]::XProperty, $anim)
    } else {
        $strip.LitBrush.Transform = [System.Windows.Media.Transform]::Identity
        $strip.Lit.HorizontalAlignment = "Left"; $strip.Lit.Width = 0.0; $strip.Lit.Opacity = 1.0
    }
}
