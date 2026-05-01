(function() {
  var saved = localStorage.getItem("theme");
  var dark = saved ? saved === "dark" : window.matchMedia("(prefers-color-scheme: dark)").matches;
  document.documentElement.setAttribute("data-theme", dark ? "dark" : "light");
})();

function toggleTheme() {
  var current = document.documentElement.getAttribute("data-theme");
  var next = current === "dark" ? "light" : "dark";
  document.documentElement.setAttribute("data-theme", next);
  localStorage.setItem("theme", next);
}

// Scroll progress indicator — fills horizontally as the page scrolls.
(function() {
  function updateScrollProgress() {
    var bar = document.getElementById("scroll-progress");
    if (!bar) return;
    var max = document.documentElement.scrollHeight - window.innerHeight;
    var progress = max > 0 ? window.scrollY / max : 0;
    if (progress < 0) progress = 0;
    if (progress > 1) progress = 1;
    bar.style.transform = "scaleX(" + progress + ")";
  }

  function init() {
    updateScrollProgress();
    window.addEventListener("scroll", updateScrollProgress, { passive: true });
    window.addEventListener("resize", updateScrollProgress, { passive: true });
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", init);
  } else {
    init();
  }
})();
