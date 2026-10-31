import { Controller } from "@hotwired/stimulus"

// show / hide password
export default class extends Controller {
  static targets = ["input"]
  toggle() { this.inputTarget.type = this.inputTarget.type === "password" ? "text" : "password" }
}
