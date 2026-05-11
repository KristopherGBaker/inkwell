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

function toggleNav(btn) {
  var open = btn.getAttribute("aria-expanded") === "true";
  var next = open ? "false" : "true";
  btn.setAttribute("aria-expanded", next);
  document.documentElement.setAttribute("data-nav-open", next);
}

// Mobile nav drawer: close on link tap, Escape, or resize past breakpoint.
(function() {
  function closeNav() {
    var btn = document.querySelector(".nav-toggle");
    if (!btn) return;
    btn.setAttribute("aria-expanded", "false");
    document.documentElement.setAttribute("data-nav-open", "false");
  }
  document.addEventListener("click", function(e) {
    var link = e.target.closest(".top-nav-links .nav-link");
    if (link) closeNav();
  });
  document.addEventListener("keydown", function(e) {
    if (e.key === "Escape") closeNav();
  });
  window.addEventListener("resize", function() {
    if (window.innerWidth > 720) closeNav();
  }, { passive: true });
})();

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
