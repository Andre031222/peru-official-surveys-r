// One button switches the theme. Until someone presses it the site follows
// the system (light or dark); after that it remembers the choice. Uses the
// same storage key as pkgdown's lightswitch.js, which sets the theme before
// the page is painted, so there is no flash when moving between pages.
document.addEventListener("DOMContentLoaded", function () {
  var root = document.documentElement;
  var btn = document.querySelector('.navbar a[href="#theme"]');
  if (btn) {
    btn.setAttribute("role", "button");
    btn.setAttribute("title", "Cambiar tema");
    btn.addEventListener("click", function (e) {
      e.preventDefault();
      var next = root.getAttribute("data-bs-theme") === "dark" ? "light" : "dark";
      var apply = function () {
        root.setAttribute("data-bs-theme", next);
        try { localStorage.setItem("theme", next); } catch (err) {}
      };
      if (document.startViewTransition && !matchMedia("(prefers-reduced-motion: reduce)").matches) {
        document.startViewTransition(apply);
      } else {
        apply();
      }
    });
  }
});
