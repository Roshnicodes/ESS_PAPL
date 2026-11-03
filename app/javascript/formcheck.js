// Friendlier form checks on every page.
//
// 1. A completely empty expense row (e.g. an extra row added by mistake) never blocks Save / Send – the server
//    ignores such rows anyway, so its required boxes are switched off just before the browser checks the form.
//    Removed (hidden) rows are switched off the same way.
// 2. When a required box really is empty, the browser's own bubble often points at nothing: searchable dropdowns
//    and date boxes hide the real field. Instead the page scrolls to the box the user sees, marks it red and says
//    which section, row and field it is ("B. Local Travel · Row 3 · Mode of Travel – please select").

const filled = (el) => {
  if (el.type === "hidden" || el.type === "checkbox" || el.type === "radio" || el.disabled) return false
  if (el.name?.includes("[_destroy]")) return false
  const v = (el.value || "").trim()
  if (v === "") return false
  if (el.type === "number" && Number(v) === 0) return false   // 0.00 defaults do not make a row "filled"
  return true
}

function relaxRows(form) {
  form.querySelectorAll("[data-nested-row]").forEach((row) => {
    const fields = row.querySelectorAll("input, select, textarea")
    const blank = row.hidden || row.dataset.removed === "true" || ![...fields].some(filled)
    fields.forEach((el) => {
      if (blank && el.required) { el.dataset.wasRequired = "1"; el.required = false }
      else if (!blank && el.dataset.wasRequired) { el.required = true; delete el.dataset.wasRequired }
    })
  })
}

// run just before the browser validates (validation happens after the submit button's click)
document.addEventListener("click", (e) => {
  const btn = e.target.closest("button, input[type=submit]")
  if (!btn || btn.type !== "submit" || !btn.form) return
  relaxRows(btn.form)
}, true)

const visibleBox = (el) =>
  el.tomselect?.control || el._flatpickr?.altInput || (el.closest(".ts-wrapper") ? el.closest(".ts-wrapper") : el)

function describe(el) {
  const cell = el.closest("td[data-label]")
  const label = cell?.dataset.label || el.labels?.[0]?.textContent?.trim() || el.getAttribute("placeholder") || "This field"
  const row = el.closest("[data-nested-row]")
  let where = ""
  if (row) {
    const rows = [...row.parentElement.querySelectorAll(":scope > [data-nested-row]:not([hidden])")]
    const section = row.closest(".card")?.querySelector(".card-title")?.textContent?.trim().split("\n")[0]
    where = `${section ? section + " · " : ""}Row ${rows.indexOf(row) + 1} · `
  }
  const what = el.tagName === "SELECT" ? "please select" : (el.validity.valueMissing ? "please fill this" : el.validationMessage)
  return `${where}${label} – ${what}`
}

function showMessage(text) {
  document.querySelector("[data-formcheck-toast]")?.remove()
  const box = document.createElement("div")
  box.dataset.formcheckToast = ""
  box.setAttribute("role", "alert")
  box.className = "pointer-events-auto fixed inset-x-3 top-3 z-[70] mx-auto flex max-w-md items-start gap-3 rounded-xl border border-rose-200 bg-white px-4 py-3 text-sm font-medium text-rose-800 shadow-xl sm:top-5"
  box.textContent = text
  document.body.appendChild(box)
  setTimeout(() => box.remove(), 6000)
}

let shown = false
document.addEventListener("invalid", (e) => {
  const el = e.target
  e.preventDefault()                       // no browser bubble pointing at a hidden field
  const box = visibleBox(el)
  box.classList.add("field-error")
  el.classList.add("field-error")
  const clear = () => { box.classList.remove("field-error"); el.classList.remove("field-error") }
  el.addEventListener("change", clear, { once: true })
  el.addEventListener("input", clear, { once: true })
  if (shown) return                        // only the first empty box of this attempt gets the message
  shown = true
  setTimeout(() => { shown = false }, 300)
  box.scrollIntoView({ block: "center", behavior: "smooth" })
  setTimeout(() => (el.tomselect ? el.tomselect.focus() : box.focus?.({ preventScroll: true })), 350)
  showMessage(describe(el))
}, true)
