import { Controller } from "@hotwired/stimulus"

// Tour plan visit: show train quota and the approval route for the selected mode.
export default class extends Controller {
  static targets = ["mode", "quota", "ticket", "approval", "approvalText"]
  static values = { trains: Array, approvals: Object }

  connect() { this.toggle() }

  toggle() {
    const isTrain = this.trainsValue.includes(Number(this.modeTarget.value))
    this.quotaTarget.hidden = !isTrain
    if (!isTrain) this.ticketTarget.value = "normal"

    const route = this.approvalsValue[this.modeTarget.value]
    if (!route) {
      this.approvalTarget.hidden = true
      return
    }

    const tatkal = isTrain && this.ticketTarget.value === "tatkal"
    const approvers = [...new Set([...(tatkal ? route.tatkal_approvers : []), ...route.approvers])]
    this.approvalTarget.hidden = false
    this.approvalTextTarget.textContent = approvers.length > 0
      ? `Additional approval for this selection: ${approvers.join(" → ")}.`
      : "No additional approval is needed for this mode."
  }
}
