# What does the window say its native hit-test is at the trigger's location?
Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public class Hit {
  [DllImport("user32.dll")] public static extern IntPtr SendMessage(IntPtr h, uint msg, IntPtr wp, IntPtr lp);
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
  [DllImport("user32.dll")] public static extern IntPtr WindowFromPoint(POINT p);
  [StructLayout(LayoutKind.Sequential)] public struct RECT { public int L, T, R, B; }
  [StructLayout(LayoutKind.Sequential)] public struct POINT { public int X, Y; }
  public static int NcHitTest(IntPtr h, int sx, int sy) {
    RECT r; GetWindowRect(h, out r);
    IntPtr lp = (IntPtr)(((sy - r.T) << 16) | ((sx - r.L) & 0xFFFF));
    return (int)SendMessage(h, 0x0084, IntPtr.Zero, lp); // WM_NCHITTEST
  }
  public static string Name(int v) {
    switch (v) {
      case 0: return "HTNOWHERE"; case 1: return "HTCLIENT"; case 2: return "HTCAPTION";
      case 3: return "HTSYSMENU"; case 8: return "HTMINBUTTON"; case 9: return "HTMAXBUTTON";
      case 10: return "HTLEFT"; case 11: return "HTRIGHT"; case 12: return "HTTOP";
      case 20: return "HTCLOSE"; case -1: return "HTTRANSPARENT";
      default: return "code " + v;
    }
  }
}
"@
$h = [IntPtr]66836
foreach ($pt in @(@(700, 20), @(775, 26), @(775, 46), @(900, 20), @(1400, 20), @(775, 200), @(775, 60))) {
  $r = [Hit]::NcHitTest($h, $pt[0], $pt[1])
  Write-Output ("NCHITTEST screen " + $pt[0] + "," + $pt[1] + " -> " + $r + " (" + [Hit]::Name($r) + ")")
}
