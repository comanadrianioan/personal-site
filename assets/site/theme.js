// Theme switch: cycles system -> light -> dark. "system" removes the choice and lets
// prefers-color-scheme decide; the inline script in <head> applies a saved choice early.
(function () {
  var btn = document.querySelector(".theme-toggle");
  if (!btn) return;
  var order = ["system", "light", "dark"];
  var names = { system: "System", light: "Light", dark: "Dark" };

  function render(mode) {
    var next = order[(order.indexOf(mode) + 1) % order.length];
    btn.dataset.mode = mode;
    btn.setAttribute("aria-label", "Theme: " + names[mode] + ". Switch to " + names[next].toLowerCase());
    btn.title = "Theme: " + names[mode];
  }

  function apply(mode) {
    var root = document.documentElement;
    if (mode === "system") delete root.dataset.theme;
    else root.dataset.theme = mode;
    try {
      if (mode === "system") localStorage.removeItem("theme");
      else localStorage.setItem("theme", mode);
    } catch (e) {}
    render(mode);
  }

  render(document.documentElement.dataset.theme || "system");
  btn.hidden = false;
  btn.addEventListener("click", function () {
    apply(order[(order.indexOf(btn.dataset.mode) + 1) % order.length]);
  });
})();
