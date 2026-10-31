import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "counter"]
  static values = { max: Number }
  connect() { this.update() }
  update() {
    const n = this.inputTarget.value.length
    this.counterTarget.textContent = `${n} / ${this.maxValue}`
    this.counterTarget.classList.toggle("text-rose-500", n >= this.maxValue)
  }
}
