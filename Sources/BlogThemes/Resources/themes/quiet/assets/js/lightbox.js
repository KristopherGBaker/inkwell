// Click-to-enlarge lightbox for content images. Opens the original image
// (its data-full URL, falling back to the displayed source) in a full-screen
// overlay. Vanilla and dependency-free, matching the rest of the theme JS.
(function() {
  var SELECTOR = ".prose img, .case-study-shots img";
  var overlay, overlayImg, overlayCaption, closeButton, lastFocused;

  function eligible(img) {
    // Leave author-linked images, diagram nodes, and opt-outs alone.
    return !img.closest("a") && !img.closest(".mermaid") && !img.classList.contains("no-zoom");
  }

  function build() {
    overlay = document.createElement("div");
    overlay.className = "lightbox-overlay";
    overlay.setAttribute("role", "dialog");
    overlay.setAttribute("aria-modal", "true");
    overlay.hidden = true;

    closeButton = document.createElement("button");
    closeButton.type = "button";
    closeButton.className = "lightbox-close";
    closeButton.setAttribute("aria-label", "Close");
    closeButton.innerHTML = "&times;";
    closeButton.addEventListener("click", close);

    var figure = document.createElement("figure");
    figure.className = "lightbox-figure";

    overlayImg = document.createElement("img");
    overlayImg.className = "lightbox-image";
    overlayImg.alt = "";
    figure.appendChild(overlayImg);

    overlayCaption = document.createElement("figcaption");
    overlayCaption.className = "lightbox-caption";
    figure.appendChild(overlayCaption);

    overlay.appendChild(closeButton);
    overlay.appendChild(figure);
    overlay.addEventListener("click", function(e) {
      // Click outside the image (backdrop or figure padding) closes.
      if (e.target === overlay || e.target === figure || e.target === overlayCaption) close();
    });
    document.body.appendChild(overlay);
  }

  function open(img) {
    if (!overlay) build();
    lastFocused = document.activeElement;
    overlayImg.src = img.getAttribute("data-full") || img.currentSrc || img.src;
    var caption = img.getAttribute("alt") || "";
    overlayImg.alt = caption;
    overlayCaption.textContent = caption;
    overlayCaption.style.display = caption ? "" : "none";
    overlay.hidden = false;
    document.documentElement.classList.add("lightbox-open");
    closeButton.focus();
  }

  function close() {
    if (!overlay || overlay.hidden) return;
    overlay.hidden = true;
    document.documentElement.classList.remove("lightbox-open");
    overlayImg.removeAttribute("src");
    if (lastFocused && typeof lastFocused.focus === "function") lastFocused.focus();
  }

  function init() {
    var imgs = document.querySelectorAll(SELECTOR);
    if (!imgs.length) return;
    Array.prototype.forEach.call(imgs, function(img) {
      if (!eligible(img)) return;
      img.classList.add("lightbox-trigger");
      img.setAttribute("role", "button");
      img.setAttribute("tabindex", "0");
      var label = img.getAttribute("alt");
      img.setAttribute("aria-label", label ? label + " (view larger)" : "View larger image");
      img.addEventListener("click", function() { open(img); });
      img.addEventListener("keydown", function(e) {
        if (e.key === "Enter" || e.key === " " || e.key === "Spacebar") {
          e.preventDefault();
          open(img);
        }
      });
    });
    document.addEventListener("keydown", function(e) {
      if (e.key === "Escape") close();
    });
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", init);
  } else {
    init();
  }
})();
