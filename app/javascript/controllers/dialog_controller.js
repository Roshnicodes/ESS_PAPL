import { Controller } from "@hotwired/stimulus"

// <button data-action="dialog#open" data-dialog-id-param="dlg-12"> opens <dialog id="dlg-12">
export default class extends Controller {
  open(event) {
    const dlg = document.getElementById(event.params.id)
    dlg?.showModal()
    // optional: mark related notifications read and drop the red badge
    if (event.params.readUrl) {
      const token = document.querySelector("meta[name='csrf-token']")?.content
      fetch(event.params.readUrl, { method: "PATCH", headers: { "X-CSRF-Token": token } })
      event.currentTarget.querySelector("[data-badge]")?.remove()
    }
  }
  close(event) {
    event.target.closest("dialog")?.close()
  }
  // click on the dark backdrop closes it
  backdrop(event) {
    if (event.target.tagName === "DIALOG") event.target.close()
  }
}
