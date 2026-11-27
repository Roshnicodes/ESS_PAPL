import { Controller } from "@hotwired/stimulus"

// Special DA Rate form: shows the Level / Designation / Employee list that fits the chosen type (only that one is
// sent), opens the city checklist for "Selected cities", filters it and counts the ticked cities.
// Method names avoid Stimulus' own members (a method called `scope` breaks `this.element`).
export default class extends Controller {
  static targets = ["value", "cityBox", "city", "cityFilter", "counter"]

  connect() { this.chooseType(); this.chooseCities(); this.countCities() }

  chooseType() {
    const chosen = this.element.querySelector('input[name="da_rate_rule[match_type]"]:checked')?.value
    this.valueTargets.forEach((box) => {
      const on = box.dataset.type === chosen
      box.hidden = !on
      const select = box.querySelector("select")
      select.disabled = !on
      select.required = on
      if (select.tomselect) on ? select.tomselect.enable() : select.tomselect.disable()
    })
  }

  chooseCities() {
    const some = this.element.querySelector('input[name="city_scope"]:checked')?.value === "some"
    this.cityBoxTarget.hidden = !some
  }

  filterCities() {
    const q = this.cityFilterTarget.value.trim().toLowerCase()
    this.cityTargets.forEach((el) => { el.hidden = q !== "" && !el.dataset.name.includes(q) })
  }

  selectShown() { this.visibleBoxes().forEach((c) => { c.checked = true }); this.countCities() }
  clearCities() { this.cityTargets.forEach((el) => { el.querySelector("input").checked = false }); this.countCities() }

  countCities() {
    this.counterTarget.textContent = this.cityTargets.filter((el) => el.querySelector("input").checked).length
  }

  visibleBoxes() { return this.cityTargets.filter((el) => !el.hidden).map((el) => el.querySelector("input")) }
}
