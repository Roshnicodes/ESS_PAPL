import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() { this.timer = setTimeout(() => this.close(), 6000) }
  disconnect() { clearTimeout(this.timer) }
  close() {
    this.element.style.transition = "opacity .2s, transform .2s"
    this.element.style.opacity = "0"
    this.element.style.transform = "translateY(-6px)"
    setTimeout(() => this.element.remove(), 200)
  }
}
