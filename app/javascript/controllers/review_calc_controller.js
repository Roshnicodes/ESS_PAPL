import { Controller } from "@hotwired/stimulus"

// Reviewer deductions: row total = amount − deduction, then section sub totals, grand total, balance – live.
export default class extends Controller {
  static values = { advance: Number }

  recalc() {
    let grand = 0
    this.element.querySelectorAll("[data-review-section]").forEach((section) => {
      let sub = 0
      section.querySelectorAll("[data-review-row]").forEach((row) => {
        const amount = parseFloat(row.dataset.amount) || 0
        const input = row.querySelector("[data-review-deduction]")
        let ded = parseFloat(input?.value) || 0
        if (input) input.classList.toggle("field-error", ded > amount || ded < 0)
        ded = Math.min(Math.max(ded, 0), amount)
        const total = amount - ded
        const cell = row.querySelector("[data-review-total]")
        if (cell) cell.textContent = this.money(total)
        sub += total
      })
      const s = section.querySelector("[data-review-sub]")
      if (s) s.textContent = this.money(sub)
      grand += sub
    })
    this.element.querySelectorAll("[data-review-grand]").forEach((el) => { el.textContent = this.money(grand) })
    this.element.querySelectorAll("[data-review-balance]").forEach((el) => { el.textContent = this.money(grand - this.advanceValue) })
    document.querySelectorAll("[data-review-header-total]").forEach((el) => { el.textContent = this.money(grand) })
  }

  money(v) { return "₹" + v.toLocaleString("en-IN", { minimumFractionDigits: 2, maximumFractionDigits: 2 }) }
}
