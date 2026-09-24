# DRAG PROBE v4: stop relying on the (apparently inert) injected stylesheet.
# Apply the fix with ELEMENT-LEVEL inline styles, keep retrying while the header mounts,
# and report sheet state + marked elements through the accessibility channel.
$p = "D:\DSH\DSH Desktop\resources\app\out\preload\index.cjs"
$t = Get-Content -Raw -Encoding UTF8 $p

# remove probe v3 (everything from its marker to end of file)
$i = $t.IndexOf("// ==== DRAG PROBE v3")
if ($i -lt 0) { Write-Output "!! v3 marker not found"; exit 1 }
$t = $t.Substring(0, $i).TrimEnd()
Write-Output "removed probe v3"

$probe = @'

// ==== DRAG PROBE v4 (temporary local diagnostic + inline-style fix; safe to delete) ====
(function () {
  function mark() {
    var marked = 0;
    var strip = document.getElementById("dsh-desktop-windows-drag-region");
    function markEl(el, why) {
      if (!el) return false;
      if (!el.hasAttribute("data-dsh-no-drag")) { el.setAttribute("data-dsh-no-drag", why); marked++; }
      el.style.setProperty("-webkit-app-region", "no-drag", "important");
      return true;
    }
    var row = document.querySelector("[class*='titleRow']");
    if (row) {
      markEl(row, "titleRow");
      var acts = row.querySelector("[class*='headerActions']");
      if (acts) markEl(acts, "headerActions");
    }
    // belt and braces: anything living in the top 44 CSS px that is not the drag strip
    var all = document.querySelectorAll("button, a, input, select, textarea, [role='button'], [class*='QsffPG_trigger'], [class*='wSkVaW_crumb']");
    for (var i = 0; i < all.length; i++) {
      var el2 = all[i];
      if (strip && (el2 === strip || strip.contains(el2))) continue;
      var r = el2.getBoundingClientRect();
      if (r.height > 0 && r.top < 44 && r.bottom > 0) markEl(el2, "topband@" + Math.round(r.top));
    }
    return marked;
  }

  var tries = 0, reported = false, totalMarked = 0;
  function report(markedNow) {
    var out = [];
    out.push("time=" + new Date().toISOString());
    var styleEl = document.getElementById("dsh-desktop-windows-titlebar-layout-style");
    var rules = "n/a";
    try { rules = styleEl && styleEl.sheet ? styleEl.sheet.cssRules.length : "sheet=null"; } catch (e) { rules = "THREW:" + e.name; }
    out.push("layout style: present=" + !!styleEl + " sheetRules=" + rules);
    var strip = document.getElementById("dsh-desktop-windows-drag-region");
    if (strip) {
      var sc = getComputedStyle(strip), sr = strip.getBoundingClientRect();
      out.push("strip rect=" + [sr.left, sr.top, sr.width, sr.height].map(Math.round).join(",") +
        " region=" + (sc.webkitAppRegion || sc.getPropertyValue("-webkit-app-region")) + " z=" + sc.zIndex + " inlineStyle=" + (strip.getAttribute("style") || "").slice(0, 90));
    }
    out.push("marked this pass=" + markedNow + " total=" + totalMarked);
    var row = document.querySelector("[class*='titleRow']");
    if (row) {
      var rc = getComputedStyle(row), rr = row.getBoundingClientRect();
      out.push("titleRow rect=" + [rr.left, rr.top, rr.width, rr.height].map(Math.round).join(",") +
        " region=" + (rc.webkitAppRegion || rc.getPropertyValue("-webkit-app-region")) + " z=" + rc.zIndex + " pos=" + rc.position +
        " attr=" + (row.getAttribute("data-dsh-no-drag") || "-"));
    } else { out.push("titleRow: NOT PRESENT"); }
    var trig = document.querySelector("[class*='QsffPG_trigger']");
    if (trig) {
      var tc = getComputedStyle(trig), tr = trig.getBoundingClientRect();
      var px = Math.round(tr.left + tr.width / 2);
      out.push("trigger rect=" + [tr.left, tr.top, tr.width, tr.height].map(Math.round).join(",") +
        " region=" + (tc.webkitAppRegion || tc.getPropertyValue("-webkit-app-region")) + " attr=" + (trig.getAttribute("data-dsh-no-drag") || "-"));
      out.push("elementFromPoint(" + px + ",20)=" + (function () { var h = document.elementFromPoint(px, 20); return h ? h.tagName + "." + (h.className || "").toString().split(" ")[0] : "null"; })());
      // inline style wins over the sheet: report whether ours is actually set on the element
      out.push("trigger inline appRegion=" + (trig.style.getPropertyValue("-webkit-app-region") || "(unset)"));
    } else { out.push("trigger: NOT PRESENT (no jobs)"); }
    // does an inline-marked element report style-level success at all?
    var anyMarked = document.querySelector("[data-dsh-no-drag]");
    out.push("first marked element=" + (anyMarked ? (anyMarked.tagName + "." + (anyMarked.className || "").toString().split(" ")[0] + " style='" + (anyMarked.getAttribute("style") || "").slice(0, 80) + "'") : "none"));
    out.push("dpr=" + window.devicePixelRatio + " viewport=" + window.innerWidth + "x" + window.innerHeight);

    var text = out.join("\n");
    try { console.log("[DRAGPROBE4]\n" + text); } catch (e) { }
    try {
      var old = document.getElementById("dsh-dragprobe-banner");
      if (old) old.remove();
      var box = document.createElement("pre");
      box.id = "dsh-dragprobe-banner";
      box.textContent = text;
      box.style.cssText = "position:fixed;left:8px;bottom:8px;z-index:2147483647;max-width:52vw;max-height:46vh;overflow:auto;background:#111;color:#0f0;font:11px/14px monospace;padding:8px;border-radius:8px;white-space:pre-wrap;user-select:text";
      document.body.appendChild(box);
    } catch (e) { }
    try {
      var host = document.getElementById("dsh-dragprobe-a11y");
      if (!host) { host = document.createElement("div"); host.id = "dsh-dragprobe-a11y"; host.style.cssText = "position:fixed;left:-20000px;top:0;width:1px;height:1px;overflow:hidden"; document.body.appendChild(host); }
      host.innerHTML = "";
      var lines = text.split("\n");
      for (var li = 0; li < lines.length && li < 40; li++) {
        var s = document.createElement("span");
        s.setAttribute("aria-label", "DP" + (li < 10 ? "0" + li : li) + " " + lines[li]);
        s.textContent = ".";
        host.appendChild(s);
      }
    } catch (e) { }
  }

  var timer = setInterval(function () {
    tries++;
    try { totalMarked += mark(); } catch (e) { }
    var trig = document.querySelector("[class*='QsffPG_trigger']");
    if (!reported && trig) { reported = true; report(0); }
    if (!reported && tries % 10 === 0) report(0);
    if (tries > 400) clearInterval(timer);
  }, 1000);
})();
// ==== end DRAG PROBE v4 ====
'@

Set-Content -Path $p -Value ($t + "`r`n" + $probe + "`r`n") -Encoding UTF8 -NoNewline
node --check $p
Write-Output ("node --check exit=" + $LASTEXITCODE + "  size=" + (Get-Item $p).Length)
Write-Output ("sha256=" + (Get-FileHash $p -Algorithm SHA256).Hash)
