import { Controller } from "@hotwired/stimulus"

// Add/remove rows for accepts_nested_attributes_for tables.
export default class extends Controller {
  static targets = ["container", "template"]

  add(event) {
    event.preventDefault()
    this.containerTarget.insertAdjacentHTML("beforeend", this.newRowHtml())
    this.focusFirst(this.containerTarget.lastElementChild)
    this.dispatch("changed", { bubbles: true })
  }

  // "+" inside a row: insert the new row right below it
  addAfter(event) {
    event.preventDefault()
    const row = event.target.closest("[data-nested-row]")
    row.insertAdjacentHTML("afterend", this.newRowHtml())
    this.focusFirst(row.nextElementSibling)
    this.dispatch("changed", { bubbles: true })
  }

  newRowHtml() {
    return this.templateTarget.innerHTML.replace(/NEW_RECORD/g, `${Date.now()}${Math.floor(Math.random() * 1000)}`)
  }

  // bring the new row into view without focusing it (focusing a date box would pop the calendar open)
  focusFirst(row) {
    setTimeout(() => row?.scrollIntoView({ block: "nearest", behavior: "smooth" }), 50)
  }

  remove(event) {
    event.preventDefault()
    const row = event.target.closest("[data-nested-row]")
    if (row.dataset.newRecord === "true") {
      row.remove()
    } else {
      row.querySelector("input[name*='_destroy']").value = "1"
      row.hidden = true
      row.dataset.removed = "true"
    }
    this.dispatch("changed", { bubbles: true })
  }
}
