# v8: locate the trigger by the button's own UIA ClickablePoint and hit-test a 3x3 grid over it.
Add-Type -AssemblyName UIAutomationClient
Add-Type -AssemblyName UIAutomationTypes
$auto = [System.Windows.Automation.AutomationElement]
$root = $auto::RootElement
$trueCond = [System.Windows.Automation.Condition]::TrueCondition
$cond = New-Object System.Windows.Automation.PropertyCondition($auto::ClassNameProperty, "Chrome_WidgetWin_1")
$win = $null
foreach ($w in $root.FindAll([System.Windows.Automation.TreeScope]::Children, $cond)) {
  try { $r = $w.Current.BoundingRectangle } catch { continue }
  if ($r.Width -gt 500) { $win = $w }
}
function Get-Trigger {
  foreach ($e in $win.FindAll([System.Windows.Automation.TreeScope]::Descendants, $trueCond)) {
    if ($e.Current.Name -match '个后台任务') { return $e }
  }
  return $null
}
$t = Get-Trigger
if (-not $t) { Write-Output "no trigger"; exit 2 }
$r = $t.Current.BoundingRectangle
Write-Output ("rect = " + [int]$r.X + "," + [int]$r.Y + " " + [int]$r.Width + "x" + [int]$r.Height)
try {
  $cp = $t.GetClickablePoint()
  Write-Output ("clickablePoint = " + [int]$cp.X + "," + [int]$cp.Y + "  (has = " + $t.Current.IsKeyboardFocusable + ")")
} catch { Write-Output ("clickablePoint failed: " + $_.Exception.Message) }

foreach ($fx in 0.12, 0.5, 0.88) {
  foreach ($fy in 0.2, 0.5, 0.8) {
    $x = [int]($r.X + $r.Width * $fx); $y = [int]($r.Y + $r.Height * $fy)
    $hit = $auto::FromPoint([System.Windows.Point]::new($x, $y))
    Write-Output ("  hit " + $x + "," + $y + " -> " + $hit.Current.ControlType.ProgrammaticName + " name='" + $hit.Current.Name + "' class=" + $hit.Current.ClassName)
  }
}

# Is the popup on top of the message list, or covered by later siblings?
$menus = $win.FindAll([System.Windows.Automation.TreeScope]::Descendants,
  (New-Object System.Windows.Automation.PropertyCondition($auto::ClassNameProperty, "QsffPG_menu")))
Write-Output ("menu count = " + $menus.Count)
foreach ($m in $menus) {
  $mr = $m.Current.BoundingRectangle
  Write-Output ("  menu rect=" + [int]$mr.X + "," + [int]$mr.Y + " " + [int]$mr.Width + "x" + [int]$mr.Height)
  $rowItems = $m.FindAll([System.Windows.Automation.TreeScope]::Children, $trueCond)
  foreach ($li in $rowItems) {
    $lr = $li.Current.BoundingRectangle
    Write-Output ("    row '" + $li.Current.Name + "' rect=" + [int]$lr.X + "," + [int]$lr.Y + " " + [int]$lr.Width + "x" + [int]$lr.Height)
    # is the row actually the topmost element at its own centre?
    $hit = $auto::FromPoint([System.Windows.Point]::new([int]($lr.X + $lr.Width / 2), [int]($lr.Y + $lr.Height / 2)))
    Write-Output ("      hit at row centre -> " + $hit.Current.ControlType.ProgrammaticName + " class=" + $hit.Current.ClassName)
  }
}

# What is the chevron element's own rect and does hit-testing it land on the button?
foreach ($e in $win.FindAll([System.Windows.Automation.TreeScope]::Descendants, $trueCond)) {
  if ($e.Current.ClassName -match 'triggerDot|triggerOpen|QsffPG_count') {
    $er = $e.Current.BoundingRectangle
    Write-Output ("  part " + $e.Current.ClassName + " name='" + $e.Current.Name + "' rect=" + [int]$er.X + "," + [int]$er.Y + " " + [int]$er.Width + "x" + [int]$er.Height)
  }
}
