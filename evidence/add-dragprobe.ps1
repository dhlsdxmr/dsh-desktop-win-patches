# Append a ONE-SHOT drag-region diagnostic to the preload (isolated world).
# Runs ~6s after UI init, writes the findings to %TEMP%\dsh-dragprobe.txt.
$p = "D:\DSH\DSH Desktop\resources\app\out\preload\index.cjs"
$t = Get-Content -Raw -Encoding UTF8 $p
if ($t -match 'DRAG PROBE v1') { Write-Output "probe already present"; exit 0 }

$probe = @'

// ==== DRAG PROBE v1 (temporary local diagnostic; safe to delete) ====
setTimeout(function () {
  try {
    var NO_DRAG_SEL = [
      "body.dsh-desktop-windows-titlebar-layout [data-dsh-no-drag]",
      "body.dsh-desktop-windows-titlebar-layout [data-slot=\"conversation.session.header\"] > header [class*=\"headerActions\"]",
      "body.dsh-desktop-windows-titlebar-layout [data-slot=\"conversation.session.header\"] > header > div:first-child",
      "body.dsh-desktop-windows-titlebar-layout [data-slot=\"conversation.session.header\"] > header > div:first-child *"
    ];
    var out = [];
    var bodyClass = document.body.className;
    out.push("body.class = " + bodyClass + " | has titlebar class = " + document.body.classList.contains("dsh-desktop-windows-titlebar-layout"));
    out.push("viewport = " + window.innerWidth + "x" + window.innerHeight + " dpr=" + window.devicePixelRatio);
    var styleEl = document.getElementById("dsh-desktop-windows-titlebar-layout-style");
    out.push("layout style tag present = " + !!styleEl + " | contains headerActions rule = " + (styleEl ? String(styleEl.textContent.indexOf("headerActions") >= 0) : "n/a"));
    var strip = document.getElementById("dsh-desktop-windows-drag-region");
    if (strip) {
      var sc = getComputedStyle(strip);
      var sr = strip.getBoundingClientRect();
      out.push("strip: rect=" + [sr.left, sr.top, sr.width, sr.height].map(Math.round).join(",") +
        " zIndex=" + sc.zIndex + " position=" + sc.position + " height=" + sc.height +
        " appRegion=" + (sc.webkitAppRegion || sc.getPropertyValue("-webkit-app-region")) +
        " pointerEvents=" + sc.pointerEvents + " parent=" + strip.parentElement.tagName + "." + strip.parentElement.className);
      var anc = [];
      var el = strip.parentElement;
      while (el && anc.length < 6) { anc.push(el.tagName + "." + (el.className || "").toString().split(" ")[0] + "{z:" + getComputedStyle(el).zIndex + ",p:" + getComputedStyle(el).position + "}"); el = el.parentElement; }
      out.push("strip ancestors: " + anc.join(" < "));
    } else {
      out.push("strip: NOT PRESENT in DOM");
    }
    var trig = document.querySelector(".QsffPG_trigger") || document.querySelector("[class*='QsffPG_trigger']");
    if (trig) {
      var tr = trig.getBoundingClientRect();
      var pt = [Math.round(tr.left + tr.width / 2), Math.round(tr.top + tr.height / 2)];
      out.push("trigger rect=" + [tr.left, tr.top, tr.width, tr.height].map(Math.round).join(",") + " point=" + pt.join(","));
      var chain = [];
      var node = trig;
      var depth = 0;
      while (node && depth < 10) {
        var cs = getComputedStyle(node);
        chain.push("[" + depth + "] " + node.tagName + "." + (node.className || "").toString().split(" ").slice(0, 2).join(".") +
          " appRegion=" + (cs.webkitAppRegion || cs.getPropertyValue("-webkit-app-region") || "none") +
          " z=" + cs.zIndex + " pos=" + cs.position);
        node = node.parentElement;
        depth++;
      }
      out.push("trigger ancestor chain:");
      out = out.concat(chain);
      for (var i = 0; i < NO_DRAG_SEL.length; i++) {
        var m = document.querySelector(NO_DRAG_SEL[i]);
        var mc = m ? getComputedStyle(m) : null;
        out.push("rule[" + i + "] matched=" + (m ? (m.tagName + "." + (m.className || "").toString().split(" ")[0]) : "NONE") +
          " appRegion=" + (mc ? (mc.webkitAppRegion || mc.getPropertyValue("-webkit-app-region")) : "-"));
      }
      for (var k = 0; k < 4; k++) {
        var y = [12, 20, 26, 40][k];
        var hit = document.elementFromPoint(pt[0], y);
        out.push("elementFromPoint(" + pt[0] + "," + y + ") = " + (hit ? (hit.tagName + "." + (hit.className || "").toString().split(" ").slice(0, 2).join(".")) : "null"));
      }
      var pv = getComputedStyle(trig);
      out.push("trigger computed: appRegion=" + (pv.webkitAppRegion || pv.getPropertyValue("-webkit-app-region")) + " display=" + pv.display + " visibility=" + pv.visibility + " pointerEvents=" + pv.pointerEvents);
      var pr = trig.getBoundingClientRect();
      out.push("hitTest(center) = " + JSON.stringify(document.elementFromPoint(Math.round(pr.left + pr.width / 2), Math.round(pr.top + pr.height / 2)) ? (function () { var h = document.elementFromPoint(Math.round(pr.left + pr.width / 2), Math.round(pr.top + pr.height / 2)); return h.tagName + "." + (h.className || ""); })() : "null"));
    } else {
      out.push("trigger (QsffPG_trigger): NOT PRESENT in DOM");
    }
    out.push("scripts with -webkit-app-region:");
    var all = document.querySelectorAll("*");
    var found = 0;
    for (var j = 0; j < all.length && found < 12; j++) {
      var c2 = getComputedStyle(all[j]);
      var reg = c2.webkitAppRegion || c2.getPropertyValue("-webkit-app-region");
      if (reg && reg !== "none") {
        var r2 = all[j].getBoundingClientRect();
        out.push("  " + all[j].tagName + "#" + (all[j].id || "") + "." + (all[j].className || "").toString().split(" ")[0] +
          " region=" + reg + " z=" + c2.zIndex + " pos=" + c2.position + " rect=" + [r2.left, r2.top, r2.width, r2.height].map(Math.round).join(","));
        found++;
      }
    }
    if (found === 0) out.push("  (none found)");
    try {
      var fs = require("node:fs");
      var os = require("node:os");
      var path = require("node:path");
      fs.writeFileSync(path.join(os.tmpdir(), "dsh-dragprobe.txt"), out.join("\n"), "utf8");
    } catch (e1) {
      try {
        fetch("http://127.0.0.1:1/__dragprobe", { method: "POST", body: out.join("\n") }).catch(function () {});
      } catch (e2) { /* nothing else available */ }
    }
  } catch (error) {
    try {
      var fs2 = require("node:fs");
      var os2 = require("node:os");
      var path2 = require("node:path");
      fs2.writeFileSync(path2.join(os2.tmpdir(), "dsh-dragprobe.txt"), "PROBE FAILED: " + (error && error.stack ? error.stack : String(error)), "utf8");
    } catch (e3) { /* ignore */ }
  }
}, 6000);
// ==== end DRAG PROBE v1 ====
'@

$t2 = $t.TrimEnd() + "`r`n" + $probe + "`r`n"
Set-Content -Path $p -Value $t2 -Encoding UTF8 -NoNewline
node --check $p
Write-Output ("node --check exit=" + $LASTEXITCODE)
Write-Output ("size = " + (Get-Item $p).Length)
Write-Output ("sha256 = " + (Get-FileHash $p -Algorithm SHA256).Hash)
