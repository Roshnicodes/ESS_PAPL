import { Controller } from "@hotwired/stimulus"

// Off-canvas sidebar for phones/tablets; always visible from lg.
export default class extends Controller {
  static targets = ["panel", "backdrop"]

  connect() {
    this.onKey = (e) => { if (e.key === "Escape") this.close() }
    document.addEventListener("keydown", this.onKey)
  }
  disconnect() { document.removeEventListener("keydown", this.onKey) }

  open() {
    this.panelTarget.classList.remove("-translate-x-full")
    this.backdropTarget.classList.remove("opacity-0", "pointer-events-none")
    document.body.classList.add("overflow-hidden")
  }

  close() {
    this.panelTarget.classList.add("-translate-x-full")
    this.backdropTarget.classList.add("opacity-0", "pointer-events-none")
    document.body.classList.remove("overflow-hidden")
  }
}
