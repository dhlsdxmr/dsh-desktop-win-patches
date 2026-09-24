# Dump every descendant of the DSH window, then screenshot it to PNG.
Add-Type -AssemblyName UIAutomationClient
Add-Type -AssemblyName UIAutomationTypes
Add-Type -AssemblyName System.Drawing

$auto = [System.Windows.Automation.AutomationElement]
$root = $auto::RootElement
$trueCond = [System.Windows.Automation.Condition]::TrueCondition
$cond = New-Object System.Windows.Automation.PropertyCondition($auto::ClassNameProperty, "Chrome_WidgetWin_1")
$wins = $root.FindAll([System.Windows.Automation.TreeScope]::Children, $cond)
$win = $null
foreach ($w in $wins) { try { $r = $w.Current.BoundingRectangle } catch { continue }; if ($r.Width -gt 500) { $win = $w } }
if (-not $win) { Write-Output "NO WINDOW"; exit 1 }

$all = $win.FindAll([System.Windows.Automation.TreeScope]::Descendants, $trueCond)
Write-Output ("descendants: " + $all.Count)
foreach ($e in $all) {
  $ct = $e.Current.ControlType.ProgrammaticName
  $n = $e.Current.Name
  $r = $e.Current.BoundingRectangle
  Write-Output ("  " + $ct + " name='" + $n + "' class=" + $e.Current.ClassName + " rect=" + [int]$r.X + "," + [int]$r.Y + " offscreen=" + $e.Current.IsOffscreen)
}

# screenshot the window rect
Add-Type -TypeDefinition @"
using System;
using System.Drawing;
using System.Drawing.Imaging;
using System.Runtime.InteropServices;
public class Shot {
  [DllImport("user32.dll")] public static extern bool PrintWindow(IntPtr hWnd, IntPtr hdcBlt, uint nFlags);
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr hWnd, out RECT r);
  [StructLayout(LayoutKind.Sequential)] public struct RECT { public int L, T, R, B; }
  public static void Capture(IntPtr hwnd, string path) {
    RECT r; GetWindowRect(hwnd, out r);
    int w = r.R - r.L, h = r.B - r.T;
    using (Bitmap bmp = new Bitmap(w, h, PixelFormat.Format32bppArgb))
    using (Graphics g = Graphics.FromImage(bmp)) {
      IntPtr hdc = g.GetHdc();
      PrintWindow(hwnd, hdc, 2); // PW_RENDERFULLCONTENT
      g.ReleaseHdc(hdc);
      bmp.Save(path, ImageFormat.Png);
    }
  }
}
"@
$hwnd = [IntPtr]$win.Current.NativeWindowHandle
Write-Output ("hwnd=" + $hwnd)
[Shot]::Capture($hwnd, "evidence\win-before.png")
Write-Output "saved win-before.png"
