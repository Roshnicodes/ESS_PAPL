import { Controller } from "@hotwired/stimulus"

// Keeps PD Finance's BLI choices tied to the selected Project.  The complete
// mapping is supplied only on the approval page, so changing a project never
// needs a second request and cannot expose unrelated BLI codes.
export default class extends Controller {
  static targets = ["project", "lineItem", "code"]
  static values = { mappings: Array }

  connect() {
    this.refreshLineItems()
  }

  projectChanged() {
    this.lineItemTarget.dataset.selected = ""
    this.codeTarget.dataset.selected = ""
    this.refreshLineItems()
  }

  lineItemChanged() {
    this.codeTarget.dataset.selected = ""
    this.refreshCodes()
  }

  refreshLineItems() {
    const selected = this.lineItemTarget.dataset.selected || this.lineItemTarget.value
    const byId = new Map()

    this.rowsForProject().forEach((row) => byId.set(String(row.line_item_id), row.line_item_name))
    this.replaceOptions(this.lineItemTarget, byId, "Select BLI", selected)
    this.refreshCodes()
  }

  refreshCodes() {
    const selected = this.codeTarget.dataset.selected || this.codeTarget.value
    const byId = new Map()

    this.rowsForProject()
      .filter((row) => String(row.line_item_id) === this.lineItemTarget.value)
      .forEach((row) => byId.set(String(row.code_id), row.code_name))
    this.replaceOptions(this.codeTarget, byId, "Select BLI code", selected)
  }

  rowsForProject() {
    return this.mappingsValue.filter((row) => String(row.project_id) === this.projectTarget.value)
  }

  // fills the <select> and – when it is a searchable Tom Select dropdown – the visible list too
  replaceOptions(select, options, placeholder, selected) {
    const sorted = Array.from(options.entries()).sort(([, a], [, b]) => a.localeCompare(b))
    const value = options.has(String(selected)) ? String(selected) : (sorted.length === 1 ? sorted[0][0] : "")
    select.replaceChildren(new Option(placeholder, ""))
    sorted.forEach(([v, label]) => select.add(new Option(label, v)))
    select.value = value

    const ts = select.tomselect
    if (ts) {
      ts.clear(true)
      ts.clearOptions()
      ts.addOption({ value: "", text: placeholder })
      sorted.forEach(([v, label]) => ts.addOption({ value: v, text: label }))
      ts.refreshOptions(false)
      ts.setValue(value, true)          // silent: we refresh the next list ourselves
      sorted.length === 0 ? ts.disable() : ts.enable()
      ts.close()
    }
    select.disabled = sorted.length === 0
  }
}
