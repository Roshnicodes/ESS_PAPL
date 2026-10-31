import { Controller } from "@hotwired/stimulus"

// Per-km amount applies only to Local Mileage modes; tour modes are ₹0.
export default class extends Controller {
  static targets = ["local", "rate", "rateBox"]
  connect() { this.toggle() }
  toggle() {
    const local = this.localTarget.checked
    this.rateBoxTarget.classList.toggle("opacity-50", !local)
    this.rateTarget.disabled = !local
    if (!local) this.rateTarget.value = "0.00"
  }
}
