# DRAG PROBE v5: prove the preload's DOM is the document we see, then apply the fix with
# element-level inline styles (and report everything through the accessibility tree).
$p = "D:\DSH\DSH Desktop\resources\app\out\preload\index.cjs"
$t = Get-Content -Raw -Encoding UTF8 $p
$i = $t.IndexOf("// ==== DRAG PROBE v4")
if ($i -lt 0) { Write-Output "!! v4 marker not found"; exit 1 }
$t = $t.Substring(0, $i).TrimEnd()
Write-Output "removed probe v4"

$probe = @'

// ==== DRAG PROBE v5 (temporary local diagnostic + inline-style fix; safe to delete) ====
(function () {
  function el(tag, style, label, text) {
    var e = document.createElement(tag);
    e.style.cssText = style;
    if (label) e.setAttribute("aria-label", label);
    if (text !== undefined) e.textContent = text;
    return e;
  }
  // 1) sentinel: proves the preload's document is the document on screen (no styling needed)
  function sentinel(msg) {
    var s = document.getElementById("dsh-probe-sentinel");
    if (!s) { s = el("span", "position:fixed;left:-20000px;top:0;width:1px;height:1px;overflow:hidden", "", "."); s.id = "dsh-probe-sentinel"; document.body.appendChild(s); }
    s.setAttribute("aria-label", "SENTINEL " + msg);
  }
  // 2) the actual fix: mark anything in the top band with an element-level inline no-drag
  function mark() {
    var n = 0;
    var strip = document.getElementById("dsh-desktop-windows-drag-region");
    var row = document.querySelector("[class*='titleRow']");
    if (row) {
      if (!row.hasAttribute("data-dsh-no-drag")) { row.setAttribute("data-dsh-no-drag", "1"); n++; }
      row.style.setProperty("-webkit-app-region", "no-drag", "important");
    }
    var all = document.querySelectorAll("button, a, input, select, textarea, [role='button'], [class*='QsffPG_trigger']");
    for (var i = 0; i < all.length; i++) {
      var e = all[i];
      if (strip && (e === strip || strip.contains(e))) continue;
      var r = e.getBoundingClientRect();
      if (r.height > 0 && r.top < 44 && r.bottom > 0) {
        if (!e.hasAttribute("data-dsh-no-drag")) { e.setAttribute("data-dsh-no-drag", "1"); n++; }
        e.style.setProperty("-webkit-app-region", "no-drag", "important");
      }
    }
    return n;
  }
  // 3) report
  var marked = 0, tries = 0, last = null;
  function report() {
    var out = [];
    var styleEl = document.getElementById("dsh-desktop-windows-titlebar-layout-style");
    var rules = "n/a";
    try { rules = styleEl && styleEl.sheet ? styleEl.sheet.cssRules.length : "sheet=null"; } catch (e) { rules = "THREW:" + e.name; }
    out.push("layoutSheet present=" + !!styleEl + " rules=" + rules + " bodyClass=" + (document.body.classList.contains("dsh-desktop-windows-titlebar-layout")));
    var row = document.querySelector("[class*='titleRow']");
    if (row) {
      var rc = getComputedStyle(row), rr = row.getBoundingClientRect();
      out.push("titleRow rect=" + [rr.left, rr.top, rr.width, rr.height].map(Math.round).join(",") +
        " region=" + (rc.webkitAppRegion || rc.getPropertyValue("-webkit-app-region")) + " z=" + rc.zIndex + " attr=" + (row.getAttribute("data-dsh-no-drag") || "-") +
        " inline=" + (row.style.getPropertyValue("-webkit-app-region") || "(unset)"));
    } else { out.push("titleRow: NOT PRESENT"); }
    var trig = document.querySelector("[class*='QsffPG_trigger']");
    if (trig) {
      var tc = getComputedStyle(trig), tr = trig.getBoundingClientRect();
      out.push("trigger rect=" + [tr.left, tr.top, tr.width, tr.height].map(Math.round).join(",") +
        " region=" + (tc.webkitAppRegion || tc.getPropertyValue("-webkit-app-region")) + " attr=" + (trig.getAttribute("data-dsh-no-drag") || "-") +
        " inline=" + (trig.style.getPropertyValue("-webkit-app-region") || "(unset)"));
    } else { out.push("trigger: NOT PRESENT (no jobs)"); }
    out.push("markedTotal=" + marked + " tries=" + tries + " top===self:" + (window.top === window.self) + " href=" + location.href.slice(0, 60));
    return out.join(" | ");
  }
  function publish() {
    var text = report();
    try { console.log("[DRAGPROBE5] " + text); } catch (e) { }
    var host = document.getElementById("dsh-dragprobe-a11y");
    if (!host) { host = el("div", "position:fixed;left:-20000px;top:0;width:1px;height:1px;overflow:hidden", "", ""); host.id = "dsh-dragprobe-a11y"; document.body.appendChild(host); }
    host.innerHTML = "";
    var parts = text.split(" | ");
    for (var i = 0; i < parts.length && i < 20; i++) {
      var s = el("span", "", "DP" + (i < 10 ? "0" + i : i) + " " + parts[i], ".");
      host.appendChild(s);
    }
    // one visible banner, refreshed in place
    var box = document.getElementById("dsh-dragprobe-banner");
    if (!box) { box = el("pre", "position:fixed;left:8px;bottom:8px;z-index:2147483647;max-width:44vw;max-height:30vh;overflow:auto;background:#111;color:#0f0;font:11px/14px monospace;padding:8px;border-radius:8px;white-space:pre-wrap;user-select:text", "", ""); box.id = "dsh-dragprobe-banner"; document.body.appendChild(box); }
    box.textContent = "DRAGPROBE5 " + new Date().toLocaleTimeString() + "\n" + text.split(" | ").join("\n");
  }
  var timer = setInterval(function () {
    tries++;
    try { marked += mark(); } catch (e) { }
    try { sentinel("tries=" + tries + " marked=" + marked + " " + (document.querySelector("[class*='QsffPG_trigger']") ? "TRIGGER=YES" : "TRIGGER=NO")); } catch (e) { }
    publish();
    if (tries > 1200) clearInterval(timer);
  }, 2000);
  setTimeout(function () { try { sentinel("booted"); } catch (e) { } }, 500);
})();
// ==== end DRAG PROBE v5 ====
'@

Set-Content -Path $p -Value ($t + "`r`n" + $probe + "`r`n") -Encoding UTF8 -NoNewline
node --check $p
Write-Output ("node --check exit=" + $LASTEXITCODE + "  size=" + (Get-Item $p).Length)
Write-Output ("sha256=" + (Get-FileHash $p -Algorithm SHA256).Hash)
