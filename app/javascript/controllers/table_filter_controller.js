import { Controller } from "@hotwired/stimulus"

// Instant search on a short list that is all on one page: hides the rows of the
// tbody target that do not contain every typed word.
export default class extends Controller {
  static targets = ["input", "body", "empty"]

  filter() {
    const words = this.inputTarget.value.toLowerCase().split(/\s+/).filter(Boolean)
    let shown = 0
    for (const row of this.bodyTarget.children) {
      const match = words.every((w) => row.textContent.toLowerCase().includes(w))
      row.hidden = !match
      if (match) shown++
    }
    if (this.hasEmptyTarget) this.emptyTarget.hidden = shown > 0 || words.length === 0
  }
}
