# UIA probe v2: target the real DSH Desktop window by process id.
Add-Type -AssemblyName UIAutomationClient
Add-Type -AssemblyName UIAutomationTypes
$auto = [System.Windows.Automation.AutomationElement]
$root = $auto::RootElement
$trueCond = [System.Windows.Automation.Condition]::TrueCondition

$cond = New-Object System.Windows.Automation.PropertyCondition($auto::ClassNameProperty, "Chrome_WidgetWin_1")
$wins = $root.FindAll([System.Windows.Automation.TreeScope]::Children, $cond)
Write-Output ("chromium windows: " + $wins.Count)
$win = $null
foreach ($w in $wins) {
  try { $r = $w.Current.BoundingRectangle } catch { continue }
  if ($r.Width -gt 500 -and $r.Height -gt 400) {
    $win = $w
    Write-Output ("PICKED pid=" + $w.Current.ProcessId + " name='" + $w.Current.Name + "' rect=" + [int]$r.X + "," + [int]$r.Y + " " + [int]$r.Width + "x" + [int]$r.Height)
  }
}
if (-not $win) { Write-Output "NO WINDOW"; exit 1 }

# Chromium exposes its a11y tree lazily; poke it with a WM_GETOBJECT-free approach:
# just enumerate and report what is there.
$all = $win.FindAll([System.Windows.Automation.TreeScope]::Descendants, $trueCond)
Write-Output ("descendants: " + $all.Count)
$i = 0
foreach ($e in $all) {
  $n = $e.Current.Name
  $ct = $e.Current.ControlType.ProgrammaticName
  if ($n -or $ct -match 'Button|List|Menu') {
    $r = $e.Current.BoundingRectangle
    $w = 0; $h = 0
    try { $w = [int]$r.Width; $h = [int]$r.Height } catch { }
    Write-Output ("[" + $i + "] " + $ct + " name='" + $n + "' rect=" + [int]$r.X + "," + [int]$r.Y + " " + $w + "x" + $h + " offscreen=" + $e.Current.IsOffscreen)
    $i++
  }
  if ($i -gt 80) { Write-Output "...truncated"; break }
}
