import { Controller } from "@hotwired/stimulus"

// IOM / Circular form: shows the employee picker only when "Selected employees" is chosen,
// filters that list as you type, and keeps the "n selected" count up to date.
export default class extends Controller {
  static targets = ["picker", "search", "row", "count", "box"]

  connect() { this.audience(); this.recount() }

  audience() {
    const selected = this.element.querySelector("input[name='circular[audience]']:checked")?.value === "selected"
    this.pickerTarget.hidden = !selected
  }

  filter() {
    const q = this.searchTarget.value.trim().toLowerCase()
    this.rowTargets.forEach((row) => { row.hidden = q !== "" && !row.dataset.search.includes(q) })
  }

  all(event) {
    event.preventDefault()
    this.visibleBoxes().forEach((b) => { b.checked = true })
    this.recount()
  }

  none(event) {
    event.preventDefault()
    this.visibleBoxes().forEach((b) => { b.checked = false })
    this.recount()
  }

  recount() {
    const n = this.boxTargets.filter((b) => b.checked).length
    this.countTarget.textContent = n === 0 ? "No employee selected yet" : `${n} employee${n === 1 ? "" : "s"} selected`
  }

  visibleBoxes() { return this.boxTargets.filter((b) => !b.closest("[data-circular-form-target='row']").hidden) }
}
