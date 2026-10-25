// Theme switch: each click flips what is shown, light <-> dark. A choice that matches the system
// setting is not stored, so the page goes back to following the system. The inline script in
// <head> applies a stored choice before the page draws.
(function () {
  var btn = document.querySelector(".theme-toggle");
  if (!btn) return;
  var root = document.documentElement;
  var systemDark = window.matchMedia("(prefers-color-scheme: dark)");

  function system() { return systemDark.matches ? "dark" : "light"; }
  function shown() { return root.dataset.theme || system(); }

  function render() {
    var next = shown() === "dark" ? "light" : "dark";
    btn.dataset.shown = shown();
    btn.setAttribute("aria-label", "Switch to " + next + " theme");
    btn.title = "Switch to " + next + " theme";
  }

  btn.addEventListener("click", function () {
    var next = shown() === "dark" ? "light" : "dark";
    try {
      if (next === system()) localStorage.removeItem("theme");
      else localStorage.setItem("theme", next);
    } catch (e) {}
    if (next === system()) delete root.dataset.theme;
    else root.dataset.theme = next;
    render();
  });
  systemDark.addEventListener("change", render);

  render();
  btn.hidden = false;
})();
