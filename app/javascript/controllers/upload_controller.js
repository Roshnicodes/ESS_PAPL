import { Controller } from "@hotwired/stimulus"

// A native multipart upload can take a few seconds while passwords are safely
// hashed on the server. Make that state explicit and prevent a duplicate run.
export default class extends Controller {
  static targets = ["button", "label", "progress"]

  start() {
    this.buttonTarget.disabled = true
    this.buttonTarget.classList.add("cursor-wait", "opacity-75")
    this.labelTarget.textContent = "Uploading…"
    this.progressTarget.hidden = false
  }
}
