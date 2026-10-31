import flatpickr from "flatpickr"

// Every <input type="date"> / <input type="datetime-local"> shows dd/mm/yyyy (dd/mm/yyyy hh:mm) to the user.
// The real input keeps ISO values (yyyy-mm-dd), so Rails, validations and other JS keep working.
// Rows added later (nested rows) are picked up by a MutationObserver; min/max attribute changes are synced.

// Date + time fields (DA / Lodging): shown as "26 Oct 2026 · 03:00 PM" with a labelled time box in the calendar,
// so it is clear that the time also has to be set (days are counted from hours).
const opts = (el) => {
  const time = el.type === "datetime-local"
  return {
    allowInput: !time,
    altInput: true,
    altFormat: time ? "d/m/y h:i K" : "d/m/Y",   // e.g. 24/10/26 9:30 AM – short so it fits the box
    dateFormat: time ? "Y-m-d\\TH:i" : "Y-m-d",
    enableTime: time,
    time_24hr: false,
    minuteIncrement: time ? 15 : 5,
    minDate: el.getAttribute("min") || null,
    maxDate: el.getAttribute("max") || null,
    disableMobile: true,
    onReady: (_d, _s, fp) => {
      fp.altInput.className = el.className + (time ? " dt-input" : "")
      fp.altInput.placeholder = time ? "dd/mm/yy hh:mm" : "dd/mm/yyyy"
      if (time) fp.altInput.title = "Click to choose the date, then set the time (hour : minute, AM / PM)"
      if (el.required) fp.altInput.required = true
      if (time && fp.timeContainer && !fp.calendarContainer.querySelector(".dt-time-label")) {
        const label = document.createElement("div")
        label.className = "dt-time-label"
        label.innerHTML = "Set time <span>Hour : Minute · AM / PM</span>"
        fp.timeContainer.before(label)
        const done = document.createElement("button")
        done.type = "button"; done.className = "dt-done"; done.textContent = "Done"
        done.addEventListener("click", () => fp.close())
        fp.calendarContainer.appendChild(done)
      }
    },
    // picking a date in a date-time field keeps the calendar open so the time is not forgotten
    closeOnSelect: !time
  }
}

function enhance(root) {
  root.querySelectorAll?.('input[type="date"], input[type="datetime-local"]').forEach((el) => {
    if (el._flatpickr || el.closest("template")) return
    if (el.readOnly || el.disabled) return
    flatpickr(el, opts(el))
  })
}

// keep calendar limits in sync when other controllers change min / max
const attrObserver = new MutationObserver((muts) => {
  muts.forEach(({ target, attributeName }) => {
    const fp = target._flatpickr
    if (!fp) return
    fp.set(attributeName === "min" ? "minDate" : "maxDate", target.getAttribute(attributeName) || null)
  })
})

const domObserver = new MutationObserver((muts) => {
  muts.forEach((m) => m.addedNodes.forEach((n) => n.nodeType === 1 && enhance(n)))
  document.querySelectorAll("input.flatpickr-input").forEach((el) => {
    if (!el._dpWatched) { attrObserver.observe(el, { attributes: true, attributeFilter: ["min", "max"] }); el._dpWatched = true }
  })
})

document.addEventListener("turbo:load", () => {
  enhance(document)
  domObserver.observe(document.body, { childList: true, subtree: true })
  document.querySelectorAll("input.flatpickr-input").forEach((el) => {
    attrObserver.observe(el, { attributes: true, attributeFilter: ["min", "max"] }); el._dpWatched = true
  })
})

// set a value programmatically and keep the visible box in sync
export function setDate(el, value) {
  if (el._flatpickr) el._flatpickr.setDate(value || null, false)
  else el.value = value
}
window.essSetDate = setDate
