import { Controller } from "@hotwired/stimulus"

// Live preview of the claim, same formulas as the live ESS form (the server recalculates on save):
//   A / E   total = amount − deduction
//   B       Two/Four Wheeler: KM = meter to − meter from, amount column = ₹/km, total = KM × rate − deduction
//           Public Transport: meters locked at 0, KM and total typed
//   C       days from From / To date-time (same hours rule as D), rate auto-filled from the chosen city's
//           rate typed by the employee, amount = rate × days
//   D       rate auto-filled from arrival city (editable), amount = days × DA rate × applicable % / 100
//   Grand total = Σ section sub totals, Balance = grand total − advance
export default class extends Controller {
  static targets = ["section", "grand", "advance", "balance"]

  connect() { this.recalc() }

  recalc(event) {
    let grand = 0
    this.sectionTargets.forEach((section) => {
      let sub = 0
      section.querySelectorAll("[data-nested-rows-target='container'] > [data-nested-row]").forEach((row) => {
        if (row.dataset.removed === "true") return
        sub += this.row(section.dataset.section, row, event)
      })
      const cell = section.querySelector("[data-subtotal]")
      if (cell) cell.textContent = this.money(sub)
      grand += sub
    })
    this.grandTargets.forEach((el) => { el.textContent = this.money(grand) })
    const adv = this.hasAdvanceTarget ? this.num(this.advanceTarget.value) : 0
    this.balanceTargets.forEach((el) => { el.textContent = this.money(grand - adv) })
  }

  row(kind, row, event) {
    const q = (k) => row.querySelector(`[data-calc="${k}"]`)
    const changed = event?.target && row.contains(event.target) ? event.target.dataset.calc : null
    const amountEl = q("amount")
    const deduction = this.num(q("deduction")?.dataset.value)

    if (kind === "local") {
      const opt = q("mode")?.selectedOptions[0]
      const manual = opt?.dataset.manual === "true"
      const rate = this.num(opt?.dataset.rate)
      const [mf, mt, km] = [q("metfrom"), q("metto"), q("km")]
      mf.readOnly = mt.readOnly = manual
      km.readOnly = !manual
      amountEl.readOnly = !manual

      // Another mode is another basis for the row, so the figures the previous
      // mode worked out are cleared instead of being carried over.
      if (changed === "mode") { mf.value = mt.value = km.value = amountEl.value = "" }

      // Public Transport has no meter trail – its bill / ticket ref is the proof.
      const purpose = q("purpose")
      if (purpose) {
        purpose.required = manual
        purpose.placeholder = manual ? "Bill / ticket ref" : ""
      }

      if (manual) {
        this.flag(mt, "")
        q("rate").value = "0.00"
      } else {
        const bothMeters = mf.value !== "" && mt.value !== ""
        const wrongOrder = bothMeters && this.num(mt.value) < this.num(mf.value)
        this.flag(mt, wrongOrder ? "Meter To must be more than Meter From" : "")
        if (wrongOrder) km.value = ""
        else if (bothMeters) km.value = (this.num(mt.value) - this.num(mf.value)).toFixed(2)
        q("rate").value = rate.toFixed(2)
        amountEl.value = km.value === "" ? "" : (this.num(km.value) * rate).toFixed(2)
      }
      const localTotal = this.num(amountEl.value) - deduction
      const t = q("total"); if (t) t.textContent = this.money(localTotal)
      return localTotal
    }

    if (kind === "lodging" || kind === "da") {
      const city = q("city")?.selectedOptions[0]
      const other = q("other")
      if (other) other.classList.toggle("hidden", city?.text !== "Other")
      const rateEl = q("rate_in")
      const cityRate = city?.dataset.rate
      if (kind === "lodging") {
        // lodging rate is typed by the employee – only DA takes the city rate from the master
      } else if (changed === "city" && cityRate) {
        rateEl.value = cityRate
      }
      const days = q("days")
      if (kind === "lodging") {
        const from = q("dep")?.value, to = q("arr")?.value
        if (from && to) days.value = this.daDays(new Date(from), new Date(to)) || ""
        amountEl.value = (this.num(days.value) * this.num(rateEl.value)).toFixed(2)
      } else {
        const dep = q("dep")?.value, arr = q("arr")?.value
        if (dep && arr) days.value = this.daDays(new Date(dep), new Date(arr)) || ""
        amountEl.value = (this.num(days.value) * this.num(rateEl.value) * this.num(q("pct").value) / 100).toFixed(2)
      }
    }

    const total = this.num(amountEl?.value) - deduction
    const totalEl = q("total")
    if (totalEl) totalEl.textContent = this.money(total)
    return total
  }

  // red box + message under the field; also blocks Save / Send until fixed
  flag(el, message) {
    el.setCustomValidity(message)
    el.classList.toggle("field-error", !!message)
    let hint = el.parentElement.querySelector("[data-calc-hint]")
    if (message && !hint) {
      hint = document.createElement("p")
      hint.dataset.calcHint = ""
      hint.className = "mt-1 text-[11px] font-semibold leading-tight text-rose-600"
      el.insertAdjacentElement("afterend", hint)
    }
    if (hint) hint.textContent = message
  }

  num(v) { const n = parseFloat(v); return isNaN(n) ? 0 : n }
  money(v) { return "₹" + v.toLocaleString("en-IN", { minimumFractionDigits: 2, maximumFractionDigits: 2 }) }

  // same rule as ClaimDailyAllowance.days_between: full 24 h = 1 day, rest ≤6 h 25 % · below 10 h 50 % · 10 h or more 100 %
  daDays(from, to) {
    const hours = (to - from) / 3600000
    if (!(hours > 0)) return 0
    const full = Math.floor(hours / 24), rest = hours - full * 24
    const part = rest <= 0 ? 0 : rest <= 6 ? 0.25 : rest < 10 ? 0.5 : 1
    return full + part
  }
}
