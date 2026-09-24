# Replace the no-drag patch with class-token based rules and install probe v3 (retrying, multi-channel).
$p = "D:\DSH\DSH Desktop\resources\app\out\preload\index.cjs"
$t = Get-Content -Raw -Encoding UTF8 $p

# --- 1. remove probe v2 ---
$i = $t.IndexOf("// ==== DRAG PROBE v2")
if ($i -ge 0) { $t = $t.Substring(0, $i); Write-Output "removed probe v2" }
$t = $t.TrimEnd()

# --- 2. replace the step-2 no-drag rules with class-token based ones ---
$oldBlock = @'
    body.dsh-desktop-windows-titlebar-layout [data-slot="conversation.session.header"] > header > div:first-child,
    body.dsh-desktop-windows-titlebar-layout [data-slot="conversation.session.header"] > header > div:first-child * {
      -webkit-app-region: no-drag !important;
    }
'@
$newBlock = @'
    body.dsh-desktop-windows-titlebar-layout [class*="wSkVaW_header"] [class*="titleRow"],
    body.dsh-desktop-windows-titlebar-layout [class*="wSkVaW_header"] [class*="titleRow"] *,
    body.dsh-desktop-windows-titlebar-layout [class*="titleRow"],
    body.dsh-desktop-windows-titlebar-layout [class*="titleRow"] *,
    body.dsh-desktop-windows-titlebar-layout [data-slot="conversation.session.header"] > header > div:first-child,
    body.dsh-desktop-windows-titlebar-layout [data-slot="conversation.session.header"] > header > div:first-child *,
    body.dsh-desktop-windows-titlebar-layout [class*="headerActions"],
    body.dsh-desktop-windows-titlebar-layout [class*="headerActions"] * {
      -webkit-app-region: no-drag !important;
    }
'@
if ($t -notmatch [regex]::Escape($oldBlock)) { Write-Output "!! step-2 block not found verbatim; aborting" ; exit 1 }
$t = $t.Replace($oldBlock, $newBlock)
Write-Output "replaced no-drag block"

$probe = @'

// ==== DRAG PROBE v3 (temporary local diagnostic; safe to delete) ====
(function () {
  var tries = 0;
  var captured = null;
  function measure() {
    var out = [];
    var trig = document.querySelector("[class*='QsffPG_trigger']");
    if (!trig) return null;
    out.push("time=" + new Date().toISOString());
    out.push("dpr=" + window.devicePixelRatio + " viewport=" + window.innerWidth + "x" + window.innerHeight);
    var tr = trig.getBoundingClientRect();
    var px = Math.round(tr.left + tr.width / 2), py = Math.round(tr.top + tr.height / 2);
    out.push("trigger rect=" + [tr.left, tr.top, tr.width, tr.height].map(Math.round).join(",") + " center=" + px + "," + py);
    var node = trig, chain = [], d = 0;
    while (node && d < 10) {
      var cs = getComputedStyle(node);
      chain.push("[" + d + "] " + node.tagName + "." + (node.className || "").toString().split(" ").slice(0, 2).join(".") +
        " region=" + (cs.webkitAppRegion || cs.getPropertyValue("-webkit-app-region") || "none") +
        " z=" + cs.zIndex + " pos=" + cs.position);
      node = node.parentElement; d++;
    }
    out.push("ancestor chain (button -> up):"); out = out.concat(chain);
    var sels = [
      "[class*='titleRow']",
      "[class*='headerActions']",
      "[data-slot='conversation.session.header'] > header > div:first-child"
    ];
    for (var i = 0; i < sels.length; i++) {
      var m = null;
      try { m = document.querySelector(sels[i]); } catch (e) { }
      if (m) {
        var mc = getComputedStyle(m);
        out.push("sel '" + sels[i] + "' -> " + m.tagName + "." + (m.className || "").toString().split(" ")[0] +
          " region=" + (mc.webkitAppRegion || mc.getPropertyValue("-webkit-app-region")) + " z=" + mc.zIndex + " pos=" + mc.position +
          " firstChildOfHeader=" + (m.parentElement && m.parentElement.tagName === "HEADER" && m.parentElement.firstElementChild === m));
      } else { out.push("sel '" + sels[i] + "' -> NO MATCH"); }
    }
    for (var k = 0; k < 5; k++) {
      var y = [8, 14, 20, 26, 40][k];
      var hit = document.elementFromPoint(px, y);
      out.push("elementFromPoint(" + px + "," + y + ") = " + (hit ? hit.tagName + "." + (hit.className || "").toString().split(" ").slice(0, 2).join(".") : "null"));
    }
    var strip = document.getElementById("dsh-desktop-windows-drag-region");
    if (strip) {
      var sc = getComputedStyle(strip), sr = strip.getBoundingClientRect();
      out.push("strip rect=" + [sr.left, sr.top, sr.width, sr.height].map(Math.round).join(",") + " z=" + sc.zIndex + " h=" + sc.height);
    }
    out.push("app-region elements containing 'header' or 'title' in class:");
    var all = document.querySelectorAll("*"), n = 0;
    for (var j = 0; j < all.length && n < 10; j++) {
      var cls = (all[j].className || "").toString();
      if (cls.indexOf("header") < 0 && cls.indexOf("titleRow") < 0 && cls.indexOf("crumb") < 0) continue;
      var c2 = getComputedStyle(all[j]);
      var reg = c2.webkitAppRegion || c2.getPropertyValue("-webkit-app-region");
      var r2 = all[j].getBoundingClientRect();
      out.push("  " + all[j].tagName + "." + cls.split(" ")[0] + " region=" + (reg || "none") + " z=" + c2.zIndex + " pos=" + c2.position +
        " rect=" + [r2.left, r2.top, r2.width, r2.height].map(Math.round).join(","));
      n++;
    }
    return out.join("\n");
  }
  function publish(text) {
    try { console.log("[DRAGPROBE]\n" + text); } catch (e) { }
    try {
      var old = document.getElementById("dsh-dragprobe-banner");
      if (old) old.remove();
      var box = document.createElement("pre");
      box.id = "dsh-dragprobe-banner";
      box.textContent = text;
      box.style.cssText = "position:fixed;left:8px;bottom:8px;z-index:2147483647;max-width:52vw;max-height:52vh;overflow:auto;background:#111;color:#0f0;font:11px/14px monospace;padding:8px;border-radius:8px;white-space:pre-wrap;user-select:text";
      document.body.appendChild(box);
    } catch (e) { }
    try { document.title = "DRAGPROBE " + text.replace(/\s+/g, " ").slice(0, 700); } catch (e) { }
    try {
      import("node:fs").then(function (fs) {
        return import("node:os").then(function (os) {
          import("node:path").then(function (path) {
            try { (fs.default || fs).writeFileSync((path.default || path).join((os.default || os).tmpdir(), "dsh-dragprobe.txt"), text, "utf8"); } catch (e) { }
          });
        });
      }).catch(function () {
        try { require("node:fs").writeFileSync(require("node:path").join(require("node:os").tmpdir(), "dsh-dragprobe.txt"), text, "utf8"); } catch (e) { }
      });
    } catch (e) { }
  }
  var timer = setInterval(function () {
    tries++;
    if (!captured) {
      var text = measure();
      if (text) { captured = text; publish(text); }
    }
    if (tries > 60 || captured) clearInterval(timer);
  }, 3000);
})();
// ==== end DRAG PROBE v3 ====
'@

Set-Content -Path $p -Value ($t + "`r`n" + $probe + "`r`n") -Encoding UTF8 -NoNewline
node --check $p
Write-Output ("node --check exit=" + $LASTEXITCODE + "  size=" + (Get-Item $p).Length + "  sha256=" + (Get-FileHash $p -Algorithm SHA256).Hash)
