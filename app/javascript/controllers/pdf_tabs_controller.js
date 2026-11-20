import { Controller } from "@hotwired/stimulus"

// IOM page with several PDFs: the buttons switch which one the viewer shows.
export default class extends Controller {
  static targets = ["frame"]

  show(event) {
    this.frameTarget.src = `${event.params.src}#view=FitH`
    this.element.querySelectorAll("[data-action='pdf-tabs#show']").forEach((b) => {
      b.classList.toggle("btn-soft", b === event.currentTarget)
      b.classList.toggle("btn-ghost", b !== event.currentTarget)
    })
  }
}
