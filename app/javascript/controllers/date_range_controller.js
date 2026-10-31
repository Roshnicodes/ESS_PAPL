import { Controller } from "@hotwired/stimulus"

// Visit dates must lie inside Tour From-Date … To-Date (live ESS: "Invalid Date Range!").
export default class extends Controller {
  static targets = ["from", "to"]

  connect() { this.apply() }

  apply(event) {
    if (!this.hasFromTarget || !this.hasToTarget) return
    // Both dates are free to pick (past dates allowed). If To is before From, pull From back to To
    // (and vice versa) instead of blocking the calendar.
    if (this.fromTarget.value && this.toTarget.value && this.toTarget.value < this.fromTarget.value) {
      if (event?.target === this.toTarget) this.set(this.fromTarget, this.toTarget.value)
      else this.set(this.toTarget, this.fromTarget.value)
    }
    this.toTarget.removeAttribute("min")
    const from = this.fromTarget.value, to = this.toTarget.value
    this.element.querySelectorAll("[data-visit-date]").forEach((el) => {
      const rangeChanged = event?.target === this.fromTarget || event?.target === this.toTarget
      // keep already-filled visit dates inside the new range
      if (rangeChanged && el.value) {
        if (from && el.value < from) this.set(el, from)
        if (to && el.value > to) this.set(el, to)
      }
      if (from) el.min = from
      if (to) el.max = to
      if (event?.target === el && el.value && ((from && el.value < from) || (to && el.value > to))) {
        alert("Invalid Date Range!")
        this.set(el, "")
      }
    })
  }

  set(el, value) {
    if (window.essSetDate) window.essSetDate(el, value)
    else el.value = value
  }
}
