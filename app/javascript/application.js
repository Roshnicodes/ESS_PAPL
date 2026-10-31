// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "@hotwired/turbo-rails"
import "controllers"
import "datepicker"
import "searchselect"

// Header dropdowns (profile, bell): close on outside click / Esc
document.addEventListener("click", (e) => {
  document.querySelectorAll("header details[open]").forEach((d) => { if (!d.contains(e.target)) d.removeAttribute("open") })
})
document.addEventListener("keydown", (e) => {
  if (e.key === "Escape") document.querySelectorAll("header details[open]").forEach((d) => d.removeAttribute("open"))
})
