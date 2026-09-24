# Target the DSH Desktop window specifically (by owning process name), then dump the jobs trigger region.
Add-Type -AssemblyName UIAutomationClient
Add-Type -AssemblyName UIAutomationTypes
$auto = [System.Windows.Automation.AutomationElement]
$root = $auto::RootElement
$tc = [System.Windows.Automation.Condition]::TrueCondition
$cond = New-Object System.Windows.Automation.PropertyCondition($auto::ClassNameProperty, "Chrome_WidgetWin_1")

$dshPids = (Get-Process -Name "DSH Desktop" -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Id)
$win = $null
foreach ($c in $root.FindAll([System.Windows.Automation.TreeScope]::Children, $cond)) {
  if ($dshPids -contains $c.Current.ProcessId) {
    try { $r = $c.Current.BoundingRectangle } catch { continue }
    if ($r.Width -gt 500) { $win = $c }
  }
}
if (-not $win) { Write-Output "NO DSH WINDOW"; exit 1 }
$wr = $win.Current.BoundingRectangle
Write-Output ("DSH window pid=" + $win.Current.ProcessId + " rect=" + [int]$wr.X + "," + [int]$wr.Y + " " + [int]$wr.Width + "x" + [int]$wr.Height)
$n = 0
foreach ($e in $win.FindAll([System.Windows.Automation.TreeScope]::Descendants, $tc)) {
  $cn = $e.Current.ClassName
  if ($cn -match 'QsffPG|wSkVaW_header|wSkVaW_crumb|wSkVaW_tabs') {
    $r = $e.Current.BoundingRectangle
    $w = 0; $h = 0
    try { $w = [int]$r.Width; $h = [int]$r.Height } catch { }
    Write-Output ("  " + $e.Current.ControlType.ProgrammaticName + " class=" + $cn + " name='" + $e.Current.Name + "' rect=" + [int]$r.X + "," + [int]$r.Y + " " + $w + "x" + $h + " off=" + $e.Current.IsOffscreen)
    $n++
  }
}
if ($n -eq 0) { Write-Output "no header/jobs nodes found (component may be unmounted: zero jobs in this session)" }
