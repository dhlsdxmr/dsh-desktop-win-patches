# DRAG PROBE v8 = the confirmed fix + self-check.
#   * the 36px drag strip declares no-drag itself (it stays pointer-events:none, so it is invisible
#     either way) -> the title row's own no-drag finally wins  (proved by phase P1)
#   * the title row and every control in the top band get an element-level inline no-drag
#   * drag still works: the strip keeps its drag capability for the blank parts, and the tab row
#     is explicitly marked drag
$p = "D:\DSH\DSH Desktop\resources\app\out\preload\index.cjs"
$t = Get-Content -Raw -Encoding UTF8 $p
$i = $t.IndexOf("// ==== DRAG PROBE v7")
if ($i -lt 0) { Write-Output "!! v7 marker not found"; exit 1 }
$t = $t.Substring(0, $i).TrimEnd()
Write-Output "removed probe v7"

$probe = @'

// ==== DRAG PROBE v8 (the fix under test; safe to delete) ====
(function () {
  function el(tag, style, label, text) {
    var e = document.createElement(tag);
    e.style.cssText = style;
    if (label) e.setAttribute("aria-label", label);
    if (text !== undefined) e.textContent = text;
    return e;
  }
  function noDrag(e) { try { e.style.setProperty("-webkit-app-region", "no-drag", "important"); } catch (x) { } }
  function drag(e) { try { e.style.setProperty("-webkit-app-region", "drag", "important"); } catch (x) { } }

  var marked = 0, tries = 0;
  function apply() {
    var strip = document.getElementById("dsh-desktop-windows-drag-region");
    if (strip) noDrag(strip);                       // <<< the actual fix
    var row = document.querySelector("[class*='titleRow']");
    if (row) { if (!row.hasAttribute("data-dsh-no-drag")) { row.setAttribute("data-dsh-no-drag", "1"); marked++; } noDrag(row); }
    var all = document.querySelectorAll("button, a, input, select, textarea, [role='button'], [class*='QsffPG_trigger']");
    for (var i = 0; i < all.length; i++) {
      var e = all[i];
      if (strip && (e === strip || strip.contains(e))) continue;
      var r = e.getBoundingClientRect();
      if (r.height > 0 && r.top < 44 && r.bottom > 0) { if (!e.hasAttribute("data-dsh-no-drag")) { e.setAttribute("data-dsh-no-drag", "1"); marked++; } noDrag(e); }
    }
    // keep window dragging available on the tab row (it sits just below the strip)
    var tabs = document.querySelector("[class*='wSkVaW_tabs']");
    if (tabs) drag(tabs);
  }
  function report() {
    var o = [];
    var trig = document.querySelector("[class*='QsffPG_trigger']");
    var strip = document.getElementById("dsh-desktop-windows-drag-region");
    var row = document.querySelector("[class*='titleRow']");
    o.push("FIX-P8 active tries=" + tries + " marked=" + marked);
    if (strip) {
      var ss = getComputedStyle(strip);
      o.push("strip region=" + JSON.stringify(ss.getPropertyValue("-webkit-app-region")) + " h=" + Math.round(strip.getBoundingClientRect().height));
    }
    if (row) {
      var rs = getComputedStyle(row);
      o.push("titleRow region=" + JSON.stringify(rs.getPropertyValue("-webkit-app-region")) + " z=" + rs.zIndex);
    }
    if (trig) {
      var tc = getComputedStyle(trig), tr = trig.getBoundingClientRect();
      o.push("trigger region=" + JSON.stringify(tc.getPropertyValue("-webkit-app-region")) + " rect=" + [tr.left, tr.top, tr.width, tr.height].map(Math.round).join(","));
      var px = Math.round(tr.left + tr.width / 2);
      var hit = document.elementFromPoint(px, Math.round(tr.top + tr.height / 2));
      o.push("elementFromPoint=" + (hit ? hit.tagName + "." + (hit.className || "").toString().split(" ")[0] : "null"));
    } else { o.push("trigger: NOT PRESENT (no jobs)"); }
    return o.join(" | ");
  }
  function publish() {
    var text = report();
    try { console.log("[DRAGPROBE8] " + text); } catch (e) { }
    var host = document.getElementById("dsh-dragprobe-a11y");
    if (!host) { host = el("div", "position:fixed;left:-20000px;top:0;width:1px;height:1px;overflow:hidden", "", ""); host.id = "dsh-dragprobe-a11y"; document.body.appendChild(host); }
    host.innerHTML = "";
    var parts = text.split(" | ");
    for (var i = 0; i < parts.length; i++) host.appendChild(el("span", "", "DP" + (i < 10 ? "0" + i : i) + " " + parts[i], "."));
    var box = document.getElementById("dsh-dragprobe-banner");
    if (!box) { box = el("pre", "position:fixed;left:8px;bottom:8px;z-index:2147483647;max-width:40vw;max-height:24vh;overflow:auto;background:#111;color:#0f0;font:11px/14px monospace;padding:8px;border-radius:8px;white-space:pre-wrap;user-select:text", "", ""); box.id = "dsh-dragprobe-banner"; document.body.appendChild(box); }
    box.textContent = text.split(" | ").join("\n");
  }
  var timer = setInterval(function () {
    tries++;
    try { apply(); } catch (e) { }
    publish();
    if (tries > 1200) clearInterval(timer);
  }, 2000);
})();
// ==== end DRAG PROBE v8 ====
'@

Set-Content -Path $p -Value ($t + "`r`n" + $probe + "`r`n") -Encoding UTF8 -NoNewline
node --check $p
Write-Output ("node --check exit=" + $LASTEXITCODE + "  size=" + (Get-Item $p).Length)
Write-Output ("sha256=" + (Get-FileHash $p -Algorithm SHA256).Hash)
