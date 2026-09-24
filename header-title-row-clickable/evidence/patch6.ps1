# DRAG PROBE v6: test whether "-webkit-app-region" is honoured at all here, and whether the
# unprefixed "app-region" is the name that works. Applies both to the marked elements.
$p = "D:\DSH\DSH Desktop\resources\app\out\preload\index.cjs"
$t = Get-Content -Raw -Encoding UTF8 $p
$i = $t.IndexOf("// ==== DRAG PROBE v5")
if ($i -lt 0) { Write-Output "!! v5 marker not found"; exit 1 }
$t = $t.Substring(0, $i).TrimEnd()
Write-Output "removed probe v5"

$probe = @'

// ==== DRAG PROBE v6 (temporary local diagnostic + fix attempt; safe to delete) ====
(function () {
  function el(tag, style, label, text) {
    var e = document.createElement(tag);
    e.style.cssText = style;
    if (label) e.setAttribute("aria-label", label);
    if (text !== undefined) e.textContent = text;
    return e;
  }
  function setRegion(e, value) {
    e.style.setProperty("-webkit-app-region", value, "important");
    e.style.setProperty("app-region", value, "important");
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
  var marked = 0, tries = 0;
  function cssSupports(name) {
    try { return CSS.supports(name, "no-drag") ? "yes" : "no"; } catch (e) { return "err"; }
  }
  function report() {
    var o = [];
    var trig = document.querySelector("[class*='QsffPG_trigger']");
    var row = document.querySelector("[class*='titleRow']");
    var strip = document.getElementById("dsh-desktop-windows-drag-region");
    o.push("supports(webkit-app-region)=" + cssSupports("-webkit-app-region") + " supports(app-region)=" + cssSupports("app-region"));
    if (trig) {
      var cs = getComputedStyle(trig);
      o.push("trigger region=" + JSON.stringify(cs.getPropertyValue("-webkit-app-region")) + "/" + JSON.stringify(cs.getPropertyValue("app-region")) +
        " inline=" + JSON.stringify(trig.style.getPropertyValue("-webkit-app-region")) + "/" + JSON.stringify(trig.style.getPropertyValue("app-region")));
    } else { o.push("trigger: NOT PRESENT"); }
    if (row) {
      var rs = getComputedStyle(row);
      o.push("titleRow region=" + JSON.stringify(rs.getPropertyValue("-webkit-app-region")) + "/" + JSON.stringify(rs.getPropertyValue("app-region")) + " z=" + rs.zIndex);
    }
    if (strip) {
      var ss = getComputedStyle(strip);
      o.push("strip region=" + JSON.stringify(ss.getPropertyValue("-webkit-app-region")) + "/" + JSON.stringify(ss.getPropertyValue("app-region")) +
        " cssText=" + JSON.stringify((strip.getAttribute("style") || "").slice(0, 120)));
    }
    o.push("marked=" + marked + " tries=" + tries);
    return o.join(" | ");
  }
  function publish() {
    var text = report();
    try { console.log("[DRAGPROBE6] " + text); } catch (e) { }
    var host = document.getElementById("dsh-dragprobe-a11y");
    if (!host) { host = el("div", "position:fixed;left:-20000px;top:0;width:1px;height:1px;overflow:hidden", "", ""); host.id = "dsh-dragprobe-a11y"; document.body.appendChild(host); }
    host.innerHTML = "";
    var parts = text.split(" | ");
    for (var i = 0; i < parts.length && i < 20; i++) host.appendChild(el("span", "", "DP" + (i < 10 ? "0" + i : i) + " " + parts[i], "."));
    var box = document.getElementById("dsh-dragprobe-banner");
    if (!box) { box = el("pre", "position:fixed;left:8px;bottom:8px;z-index:2147483647;max-width:44vw;max-height:30vh;overflow:auto;background:#111;color:#0f0;font:11px/14px monospace;padding:8px;border-radius:8px;white-space:pre-wrap;user-select:text", "", ""); box.id = "dsh-dragprobe-banner"; document.body.appendChild(box); }
    box.textContent = text.split(" | ").join("\n");
  }
  var timer = setInterval(function () {
    tries++;
    try { marked += mark(); } catch (e) { }
    publish();
    if (tries > 1200) clearInterval(timer);
  }, 2000);
})();
// ==== end DRAG PROBE v6 ====
'@

Set-Content -Path $p -Value ($t + "`r`n" + $probe + "`r`n") -Encoding UTF8 -NoNewline
node --check $p
Write-Output ("node --check exit=" + $LASTEXITCODE + "  size=" + (Get-Item $p).Length)
Write-Output ("sha256=" + (Get-FileHash $p -Algorithm SHA256).Hash)
