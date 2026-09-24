Add-Type -AssemblyName UIAutomationClient
Add-Type -AssemblyName UIAutomationTypes
$auto=[System.Windows.Automation.AutomationElement]; $root=$auto::RootElement
$tc=[System.Windows.Automation.Condition]::TrueCondition
$cond=New-Object System.Windows.Automation.PropertyCondition($auto::ClassNameProperty,"Chrome_WidgetWin_1")
$win=$null; foreach($w in $root.FindAll([System.Windows.Automation.TreeScope]::Children,$cond)){ try{$r=$w.Current.BoundingRectangle}catch{continue}; if($r.Width -gt 500){$win=$w} }
foreach($e in $win.FindAll([System.Windows.Automation.TreeScope]::Descendants,$tc)){ if($e.Current.Name -match "个后台任务"){ $ec=$null; $null=$e.TryGetCurrentPattern([System.Windows.Automation.ExpandCollapsePattern]::Pattern,[ref]$ec); if($ec.Current.ExpandCollapseState -eq "Collapsed"){ $ec.Expand(); "expanded" } else { "already expanded" }; break } }
