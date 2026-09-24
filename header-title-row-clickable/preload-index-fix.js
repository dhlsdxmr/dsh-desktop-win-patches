
// ==== DSH local fix: keep the conversation-header title row clickable on Windows ====
// Root cause: the desktop titlebar layout mounts a transparent 36px drag strip across the top of the
// window (resources/app/out/preload/index.cjs, DRAG_REGION_ID). While that strip itself declares
// -webkit-app-region: drag, the whole band resolves as the window caption area, so no descendant can
// claim a clickable no-drag region - every control in the header title row (background-jobs dropdown,
// mode selector, session crumbs) becomes unclickable. Verified by phase experiment: setting the strip
// to no-drag flips WM_NCHITTEST at the button centre from HTCAPTION to HTCLIENT; hiding the strip does
// not (the native titleBarOverlay still claims the band), so the strip itself has to stop claiming drag.
// The strip is a transparent pointer-events:none overlay, so this changes nothing visually; dragging
// stays available on the tab row and on the blank parts of the band.
(function () {
  function noDrag(el) { try { el.style.setProperty("-webkit-app-region", "no-drag", "important"); } catch (e) { } }
  function drag(el) { try { el.style.setProperty("-webkit-app-region", "drag", "important"); } catch (e) { } }
  function apply() {
    var strip = document.getElementById("dsh-desktop-windows-drag-region");
    if (strip) noDrag(strip);
    var row = document.querySelector("[class*='titleRow']");
    if (row) {
      row.setAttribute("data-dsh-no-drag", "header-title-row");
      noDrag(row);
    }
    var controls = document.querySelectorAll("button, a, input, select, textarea, [role='button']");
    for (var i = 0; i < controls.length; i++) {
      var el2 = controls[i];
      if (strip && (el2 === strip || strip.contains(el2))) continue;
      var r = el2.getBoundingClientRect();
      if (r.height > 0 && r.top < 44 && r.bottom > 0) {
        el2.setAttribute("data-dsh-no-drag", "titlebar-band");
        noDrag(el2);
      }
    }
    var tabs = document.querySelector("[class*='wSkVaW_tabs']");
    if (tabs) drag(tabs);
  }
  var runs = 0;
  apply();
  var timer = setInterval(function () {
    runs++;
    apply();
    if (runs > 150) clearInterval(timer);
  }, 2000);
})();
// ==== end DSH local fix ====
