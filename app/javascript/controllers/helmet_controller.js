import { Controller } from "@hotwired/stimulus"

// Helmet declaration is shown (and required for Send) only when a Two Wheeler is selected in the claim.
export default class extends Controller {
  static targets = ["check", "send", "box"]

  connect() {
    this.form = this.element.closest("form")
    this.onChange = () => this.toggle()
    this.form?.addEventListener("change", this.onChange)
    this.form?.addEventListener("nested-rows:changed", this.onChange)
    this.toggle()
  }

  disconnect() {
    this.form?.removeEventListener("change", this.onChange)
    this.form?.removeEventListener("nested-rows:changed", this.onChange)
  }

  toggle() {
    const twoWheeler = [...(this.form?.querySelectorAll("select[name*='travel_mode_id']") || [])]
      .filter((s) => !s.closest("[data-removed='true']"))
      .some((s) => /two/i.test(s.selectedOptions[0]?.text || ""))
    this.boxTarget.hidden = !twoWheeler
    this.sendTarget.disabled = twoWheeler && !this.checkTarget.checked
  }
}
