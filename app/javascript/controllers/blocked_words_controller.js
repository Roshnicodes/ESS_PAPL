import { Controller } from "@hotwired/stimulus"

// Same behaviour as live ESS: project / funder names are stripped from descriptions while typing.
export default class extends Controller {
  static targets = ["input", "warning"]
  static values = { list: Array }

  connect() {
    const esc = (w) => w.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")
    this.regex = new RegExp(this.listValue.map((w) => `(?<![\\p{L}\\p{N}])${esc(w)}(?![\\p{L}\\p{N}])`).join("|"), "giu")
  }

  check() {
    if (!this.listValue.length) return
    const text = this.inputTarget.value
    const cleaned = text.replace(this.regex, "")
    if (cleaned !== text) {
      this.inputTarget.value = cleaned
      this.warningTarget.classList.remove("hidden")
    }
  }
}
