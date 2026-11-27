// Sections and cards fade in the first time they scroll into view.
document.addEventListener("DOMContentLoaded", function () {
  var items = document.querySelectorAll("main h2, main .fa-card, main pre, main img, main table");
  if (!("IntersectionObserver" in window)) return;
  var io = new IntersectionObserver(function (entries) {
    entries.forEach(function (e) {
      if (e.isIntersecting) { e.target.classList.add("fa-in"); io.unobserve(e.target); }
    });
  }, { rootMargin: "0px 0px -5% 0px" });
  items.forEach(function (el) {
    var r = el.getBoundingClientRect();
    if (r.top > window.innerHeight) { el.classList.add("fa-reveal"); io.observe(el); }
  });
});
