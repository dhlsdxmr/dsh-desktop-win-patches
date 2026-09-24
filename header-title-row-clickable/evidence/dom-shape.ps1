# Inspect the live header DOM shape through the accessibility tree: which elements exist,
# and (crucially) what class names they carry.
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
if (-not $win) { Write-Output "NO WINDOW"; exit 1 }
Write-Output ("window pid=" + $win.Current.ProcessId)
$n = 0
foreach ($e in $win.FindAll([System.Windows.Automation.TreeScope]::Descendants, $tc)) {
  $cn = $e.Current.ClassName
  if ($cn -match 'wSkVaW|headerActions|headerUtilities|headerCorner|QsffPG|pI_x6G|EvIC1a') {
    $r = $e.Current.BoundingRectangle
    $w = 0; $h = 0
    try { $w = [int]$r.Width; $h = [int]$r.Height } catch { }
    Write-Output ("  " + $e.Current.ControlType.ProgrammaticName + " class=[" + $cn + "] name='" + $e.Current.Name + "' rect=" + [int]$r.X + "," + [int]$r.Y + " " + $w + "x" + $h + " off=" + $e.Current.IsOffscreen)
    $n++
  }
}
if ($n -eq 0) { Write-Output "no matching nodes" }
Write-Output ("matched " + $n)
