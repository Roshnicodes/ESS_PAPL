import { Controller } from "@hotwired/stimulus"

// Payment Advice list: tick one row, several, or all. The action bar only appears once
// something is ticked, and it says how many claims and how much money it will cover.
export default class extends Controller {
  static targets = ["row", "all", "bar", "count", "amount", "utr", "submit"]
  static values = { currency: { type: String, default: "₹" } }

  connect() { this.refresh() }

  toggleAll() {
    this.rowTargets.forEach((box) => { box.checked = this.allTarget.checked })
    this.refresh()
  }

  refresh() {
    const picked = this.rowTargets.filter((b) => b.checked)
    const total = picked.reduce((sum, b) => sum + Number(b.dataset.amount || 0), 0)

    if (this.hasAllTarget) {
      this.allTarget.checked = picked.length > 0 && picked.length === this.rowTargets.length
      this.allTarget.indeterminate = picked.length > 0 && picked.length < this.rowTargets.length
    }
    this.rowTargets.forEach((b) => b.closest("tr")?.classList.toggle("bg-brand-50/60", b.checked))

    if (this.hasBarTarget) this.barTarget.hidden = picked.length === 0
    if (this.hasCountTarget) this.countTarget.textContent = `${picked.length} claim${picked.length === 1 ? "" : "s"}`
    if (this.hasAmountTarget) {
      this.amountTarget.textContent = this.currencyValue + total.toLocaleString("en-IN", { minimumFractionDigits: 2, maximumFractionDigits: 2 })
    }
    this.validate()
  }

  // Guard the bulk save: a UTR is required, and the confirm names what is about to happen.
  validate() {
    if (!this.hasSubmitTarget || !this.hasUtrTarget) return
    const ok = this.utrTarget.value.trim().length >= 4
    this.submitTarget.disabled = !ok
    this.submitTarget.classList.toggle("opacity-50", !ok)
    this.submitTarget.dataset.turboConfirm =
      `Record UTR ${this.utrTarget.value.trim()} on ${this.countTarget?.textContent || "the ticked claims"} (${this.amountTarget?.textContent || ""})?`
  }
}
