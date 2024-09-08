// Based on https://stackoverflow.com/a/75065536
// Set theme to the user's preferred color scheme
function updateTheme() {
  const colorMode = window.matchMedia("(prefers-color-scheme: dark)").matches
    ? "dark"
    : "light";
  document.documentElement.setAttribute("data-bs-theme", colorMode);
}

// Set theme on load
updateTheme();

// Update theme when the preferred scheme changes
window
  .matchMedia("(prefers-color-scheme: dark)")
  .addEventListener("change", updateTheme);
