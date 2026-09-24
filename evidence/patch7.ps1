# DRAG PROBE v7: phase-cycled experiment. Every ~7s it changes ONE thing about the 36px drag
# strip and publishes the phase id; an external WM_NCHITTEST sweep pins the result on each phase.
$p = "D:\DSH\DSH Desktop\resources\app\out\preload\index.cjs"
$t = Get-Content -Raw -Encoding UTF8 $p
$i = $t.IndexOf("// ==== DRAG PROBE v6")
if ($i -lt 0) { Write-Output "!! v6 marker not found"; exit 1 }
$t = $t.Substring(0, $i).TrimEnd()
Write-Output "removed probe v6"

$probe = @'

// ==== DRAG PROBE v7 (temporary local diagnostic; safe to delete) ====
(function () {
  function el(tag, style, label, text) {
    var e = document.createElement(tag);
    e.style.cssText = style;
    if (label) e.setAttribute("aria-label", label);
    if (text !== undefined) e.textContent = text;
    return e;
  }
  function setRegion(e, v) {
    try { e.style.setProperty("-webkit-app-region", v, "important"); } catch (x) { }
  }
  var phase = 0;
  var PHASES = [
    { id: "P0-baseline", note: "什么都没动" },
    { id: "P1-strip-region-none", note: "拖拽条改成 app-region:no-drag" },
    { id: "P2-strip-height0", note: "拖拽条 height:0 且 visibility:hidden" },
    { id: "P3-strip-display-none", note: "拖拽条 display:none（从布局里移除）" }
  ];
  function applyPhase() {
    var strip = document.getElementById("dsh-desktop-windows-drag-region");
    if (!strip) return "no-strip";
    // reset
    strip.style.removeProperty("display");
    try { strip.style.setProperty("-webkit-app-region", "drag", "important"); } catch (e) { }
    strip.style.removeProperty("app-region");
    strip.style.removeProperty("height");
    strip.style.removeProperty("visibility");
    if (phase === 1) strip.style.setProperty("-webkit-app-region", "no-drag", "important");
    if (phase === 2) { strip.style.setProperty("height", "0px", "important"); strip.style.setProperty("visibility", "hidden", "important"); }
    if (phase === 3) strip.style.setProperty("display", "none", "important");
    return PHASES[phase].id;
  }
  function mark() {
    var n = 0;
    var strip = document.getElementById("dsh-desktop-windows-drag-region");
    var row = document.querySelector("[class*='titleRow']");
    if (row) { if (!row.hasAttribute("data-dsh-no-drag")) { row.setAttribute("data-dsh-no-drag", "1"); n++; } setRegion(row, "no-drag"); }
    var all = document.querySelectorAll("button, a, input, select, textarea, [role='button'], [class*='QsffPG_trigger']");
    for (var i = 0; i < all.length; i++) {
      var e = all[i];
      if (strip && (e === strip || strip.contains(e))) continue;
      var r = e.getBoundingClientRect();
      if (r.height > 0 && r.top < 44 && r.bottom > 0) { if (!e.hasAttribute("data-dsh-no-drag")) { e.setAttribute("data-dsh-no-drag", "1"); n++; } setRegion(e, "no-drag"); }
    }
    return n;
  }
  var tries = 0, marked = 0;
  function publish(phaseId) {
    var trig = document.querySelector("[class*='QsffPG_trigger']");
    var strip = document.getElementById("dsh-desktop-windows-drag-region");
    var o = [];
    o.push("PHASE=" + phaseId);
    o.push("trigger=" + (trig ? "yes region=" + JSON.stringify(getComputedStyle(trig).getPropertyValue("-webkit-app-region")) : "no"));
    if (strip) {
      var ss = getComputedStyle(strip), sr = strip.getBoundingClientRect();
      o.push("strip h=" + Math.round(sr.height) + " display=" + ss.display + " region=" + JSON.stringify(ss.getPropertyValue("-webkit-app-region")));
    }
    o.push("tries=" + tries + " marked=" + marked);
    var text = o.join(" | ");
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
    try { marked += mark(); } catch (e) { }
    var id = applyPhase();
    publish(id);
    if (tries % 2 === 0) phase = (phase + 1) % PHASES.length;
    if (tries > 1200) clearInterval(timer);
  }, 2500);
})();
// ==== end DRAG PROBE v7 ====
'@

Set-Content -Path $p -Value ($t + "`r`n" + $probe + "`r`n") -Encoding UTF8 -NoNewline
node --check $p
Write-Output ("node --check exit=" + $LASTEXITCODE + "  size=" + (Get-Item $p).Length)
Write-Output ("sha256=" + (Get-FileHash $p -Algorithm SHA256).Hash)
