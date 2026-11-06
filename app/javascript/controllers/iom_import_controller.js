import { Controller } from "@hotwired/stimulus"

// Import old IOMs: the sheet (optional) + many files, sent in small batches so a big folder
// never hits the server's upload limit. Every batch carries the sheet; the server skips what it already has.
const BATCH_FILES = 8
const BATCH_BYTES = 20 * 1024 * 1024
const esc = (t) => String(t).replace(/[&<>"']/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c]))

export default class extends Controller {
  static targets = ["sheet", "folder", "picked", "count", "type", "date", "notify", "button", "bar", "fill", "status", "result", "noSheet"]
  static values = { url: String, list: String }

  pick() {
    const files = this.files()
    const size = files.reduce((s, f) => s + f.size, 0)
    this.countTarget.textContent = files.length ? `${files.length} file(s) chosen · ${(size / 1048576).toFixed(1)} MB` : "No files chosen."
  }

  files() {
    const seen = new Set()
    return [...this.folderTarget.files, ...this.pickedTarget.files].filter((f) => {
      if (f.name.startsWith(".") || seen.has(f.name.toLowerCase())) return false
      seen.add(f.name.toLowerCase()); return true
    })
  }

  batches(files) {
    const out = []; let cur = []; let bytes = 0
    files.forEach((f) => {
      if (cur.length && (cur.length >= BATCH_FILES || bytes + f.size > BATCH_BYTES)) { out.push(cur); cur = []; bytes = 0 }
      cur.push(f); bytes += f.size
    })
    if (cur.length) out.push(cur)
    return out
  }

  async start() {
    const sheet = this.sheetTarget.files[0]
    const files = this.files()
    if (!sheet && !files.length) return this.show("Choose the Excel sheet and / or the files first.", true)
    const parts = files.length ? this.batches(files) : [[]]
    const token = document.querySelector("meta[name='csrf-token']")?.content
    const total = { created: 0, files_attached: 0, already: 0, errors: new Set(), unmatched: new Set(), ids: [], notified: 0 }
    this.buttonTarget.disabled = true
    this.barTarget.hidden = false

    for (let i = 0; i < parts.length; i++) {
      this.statusTarget.textContent = `Uploading part ${i + 1} of ${parts.length}…`
      const fd = new FormData()
      if (sheet) fd.append("sheet", sheet)
      parts[i].forEach((f) => fd.append("files[]", f, f.name))
      fd.append("default_type", this.typeTarget.value)
      fd.append("default_date", this.dateTarget.value)
      const last = i === parts.length - 1
      if (last) {
        fd.append("final", "1")
        if (this.notifyTarget.checked) { fd.append("send_notification", "1"); total.ids.forEach((id) => fd.append("notify_ids[]", id)) }
      }
      let data
      try {
        const res = await fetch(this.urlValue, { method: "POST", body: fd, headers: { "X-CSRF-Token": token, Accept: "application/json" } })
        data = await res.json().catch(() => ({ error: `Server answered ${res.status}` }))
        if (!res.ok && !data.error) data.error = `Server answered ${res.status}`
      } catch (e) {
        data = { error: `Upload failed (${e.message}). Check the connection and import again – nothing is duplicated.` }
      }
      if (data.error) { this.finish(); return this.show(esc(data.error), true) }
      total.created += data.created; total.files_attached += data.files_attached
      data.errors.forEach((e) => total.errors.add(e)); total.ids.push(...data.created_ids); total.notified = data.notified || total.notified
      if (i === 0) total.already = data.already
      ;(data.unmatched_files || []).forEach((n) => total.unmatched.add(n))
      this.fillTarget.style.width = `${Math.round(((i + 1) / parts.length) * 100)}%`
    }
    this.finish()
    const lines = [
      `<b>${total.created}</b> IOM(s) created · <b>${total.files_attached}</b> file(s) attached` + (total.already ? ` · ${total.already} were already in ESS` : ""),
      total.notified ? `Email notification is going out for ${total.notified} IOM(s).` : "No email sent.",
      total.unmatched.size ? `Files not named in the sheet (not imported): ${[...total.unmatched].slice(0, 15).map(esc).join(", ")}${total.unmatched.size > 15 ? " …" : ""}` : "",
      total.errors.size ? `Problems:<br>• ${[...total.errors].slice(0, 20).map(esc).join("<br>• ")}` : "",
      `<a class="font-semibold underline" href="${this.listValue}">Open the IOM / Circular list</a>`
    ].filter(Boolean)
    this.show(lines.join("<br>"), total.errors.size > 0)
  }

  finish() {
    this.buttonTarget.disabled = false
    this.statusTarget.textContent = ""
  }

  show(html, warn) {
    const el = this.resultTarget
    el.classList.remove("hidden", "bg-emerald-50", "ring-emerald-200", "text-emerald-900", "bg-amber-50", "ring-amber-200", "text-amber-900")
    el.classList.add(...(warn ? ["bg-amber-50", "ring-amber-200", "text-amber-900"] : ["bg-emerald-50", "ring-emerald-200", "text-emerald-900"]))
    el.innerHTML = html
  }
}
