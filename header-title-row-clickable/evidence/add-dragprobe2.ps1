# Install DRAG PROBE v2: same diagnostics, but persisting through channels that exist in a
# sandboxed Electron preload (dynamic import("node:fs") / require / visible on-screen banner).
$p = "D:\DSH\DSH Desktop\resources\app\out\preload\index.cjs"
$t = Get-Content -Raw -Encoding UTF8 $p
if ($t -match 'DRAG PROBE v2') { Write-Output "v2 already present"; exit 0 }

$probe = @'

// ==== DRAG PROBE v2 (temporary local diagnostic; safe to delete) ====
setTimeout(function () {
  var out = [];
  var push = function (s) { out.push(s); };
  try {
    push("time=" + new Date().toISOString());
    push("body.class = " + (document.body ? document.body.className : "(no body)"));
    push("hasTitlebarClass = " + (document.body ? document.body.classList.contains("dsh-desktop-windows-titlebar-layout") : "?"));
    push("viewport = " + window.innerWidth + "x" + window.innerHeight + " dpr=" + window.devicePixelRatio);
    var styleEl = document.getElementById("dsh-desktop-windows-titlebar-layout-style");
    push("layoutStyleTag = " + !!styleEl + " containsHeaderActionsRule = " + (styleEl ? styleEl.textContent.indexOf("headerActions") >= 0 : "n/a"));

    var strip = document.getElementById("dsh-desktop-windows-drag-region");
    if (strip) {
      var sc = getComputedStyle(strip);
      var sr = strip.getBoundingClientRect();
      push("strip rect=" + [sr.left, sr.top, sr.width, sr.height].map(Math.round).join(",") +
        " z=" + sc.zIndex + " pos=" + sc.position + " h=" + sc.height +
        " region=" + (sc.webkitAppRegion || sc.getPropertyValue("-webkit-app-region")) +
        " pe=" + sc.pointerEvents);
      var anc = [];
      var el = strip;
      var d = 0;
      while (el && d < 7) {
        anc.push(el.tagName + "." + (el.className || "").toString().split(" ")[0] + "{z:" + getComputedStyle(el).zIndex + ",p:" + getComputedStyle(el).position + "}");
        el = el.parentElement; d++;
      }
      push("strip chain = " + anc.join(" < "));
    } else { push("strip = NOT PRESENT"); }

    var trig = document.querySelector("[class*='QsffPG_trigger']");
    if (trig) {
      var tr = trig.getBoundingClientRect();
      var px = Math.round(tr.left + tr.width / 2);
      push("trigger rect=" + [tr.left, tr.top, tr.width, tr.height].map(Math.round).join(",") + " centerX=" + px);
      var tc = getComputedStyle(trig);
      push("trigger region=" + (tc.webkitAppRegion || tc.getPropertyValue("-webkit-app-region")) + " pos=" + tc.position + " z=" + tc.zIndex);
      var node = trig, chain = [], depth = 0;
      while (node && depth < 9) {
        var cs = getComputedStyle(node);
        chain.push("[" + depth + "] " + node.tagName + "." + (node.className || "").toString().split(" ").slice(0, 2).join(".") +
          " region=" + (cs.webkitAppRegion || cs.getPropertyValue("-webkit-app-region") || "none") + " z=" + cs.zIndex + " pos=" + cs.position);
        node = node.parentElement; depth++;
      }
      push("trigger chain:"); out = out.concat(chain);
      var sels = [
        "[data-dsh-no-drag]",
        "[data-slot='conversation.session.header'] > header [class*='headerActions']",
        "[data-slot='conversation.session.header'] > header > div:first-child",
        "[data-slot='conversation.session.header'] > header > div:first-child *",
        "[data-slot='conversation.session.header']",
        "[class*='headerActions']",
        "[class*='wSkVaW_headerActions']"
      ];
      for (var i = 0; i < sels.length; i++) {
        var m = null;
        try { m = document.querySelector(sels[i]); } catch (e) { }
        if (m) {
          var mc = getComputedStyle(m);
          push("sel[" + i + "] '" + sels[i] + "' -> " + m.tagName + "." + (m.className || "").toString().split(" ")[0] +
            " region=" + (mc.webkitAppRegion || mc.getPropertyValue("-webkit-app-region")) + " z=" + mc.zIndex + " pos=" + mc.position);
        } else { push("sel[" + i + "] '" + sels[i] + "' -> NO MATCH"); }
      }
      for (var k = 0; k < 5; k++) {
        var y = [8, 14, 20, 26, 40][k];
        var hit = document.elementFromPoint(px, y);
        push("elementFromPoint(" + px + "," + y + ") = " + (hit ? hit.tagName + "." + (hit.className || "").toString().split(" ").slice(0, 2).join(".") : "null"));
      }
    } else { push("trigger = NOT PRESENT"); }

    push("all app-region elements:");
    var all = document.querySelectorAll("*"), found = 0;
    for (var j = 0; j < all.length && found < 10; j++) {
      var c2 = getComputedStyle(all[j]);
      var reg = c2.webkitAppRegion || c2.getPropertyValue("-webkit-app-region");
      if (reg && reg !== "none") {
        var r2 = all[j].getBoundingClientRect();
        push("  " + all[j].tagName + "#" + (all[j].id || "") + "." + (all[j].className || "").toString().split(" ")[0] +
          " region=" + reg + " z=" + c2.zIndex + " pos=" + c2.position + " rect=" + [r2.left, r2.top, r2.width, r2.height].map(Math.round).join(","));
        found++;
      }
    }
    if (!found) push("  (none)");
  } catch (error) {
    push("PROBE ERROR: " + (error && error.stack ? error.stack : String(error)));
  }

  var text = out.join("\n");
  // channel 1: console (lands in any attached log)
  try { console.log("[DRAGPROBE]\n" + text); } catch (e) { }
  // channel 2: a visible, selectable banner (always works)
  try {
    var box = document.createElement("pre");
    box.id = "dsh-dragprobe-banner";
    box.textContent = text;
    box.style.cssText = "position:fixed;left:8px;bottom:8px;z-index:2147483647;max-width:46vw;max-height:44vh;overflow:auto;background:#111;color:#0f0;font:11px/14px monospace;padding:8px;border-radius:8px;white-space:pre-wrap;user-select:text";
    document.body.appendChild(box);
  } catch (e) { }
  // channel 3: file, via the module systems Electron may expose here
  var write = function (fs, os, path) {
    try {
      fs.writeFileSync(path.join(os.tmpdir(), "dsh-dragprobe.txt"), text, "utf8");
      return true;
    } catch (e) { return false; }
  };
  var done = function (ok) { try { console.log("[DRAGPROBE] file=" + ok); } catch (e) { } };
  try {
    Promise.all([import("node:fs"), import("node:os"), import("node:path")]).then(function (mods) {
      var ok = write(mods[0].default || mods[0], mods[1].default || mods[1], mods[2].default || mods[2]);
      if (!ok) { try { write(require("node:fs"), require("node:os"), require("node:path")); done("require-fallback"); } catch (e) { done(false); } } else { done(true); }
    }).catch(function () {
      try { write(require("node:fs"), require("node:os"), require("node:path")); done("require-only"); } catch (e) { done(false); }
    });
  } catch (e) { done(false); }
}, 6000);
// ==== end DRAG PROBE v2 ====
'@

Set-Content -Path $p -Value ($t.TrimEnd() + "`r`n" + $probe + "`r`n") -Encoding UTF8 -NoNewline
node --check $p
Write-Output ("node --check exit=" + $LASTEXITCODE)
Write-Output ("size = " + (Get-Item $p).Length)
Write-Output ("sha256 = " + (Get-FileHash $p -Algorithm SHA256).Hash)
