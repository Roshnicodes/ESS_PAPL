import "tom-select"   // UMD build: defines window.TomSelect
const TomSelect = window.TomSelect

// Every <select> in the app becomes a searchable dropdown (search box inside the list).
// The original <select> stays in the DOM (hidden) and keeps its value, options and data-* attributes,
// and still fires "change" – so forms, Stimulus controllers and calculations work unchanged.
// Add data-no-search to a <select> to keep it native.

function enhance(root) {
  root.querySelectorAll?.("select:not([data-no-search]):not([multiple])").forEach((el) => {
    if (el.tomselect || el.closest("template")) return
    new TomSelect(el, {
      plugins: ["dropdown_input"],
      // render the list above everything (glass cards / sticky bars create stacking contexts)
      dropdownParent: el.closest("dialog") || "body",
      allowEmptyOption: true,
      maxOptions: null,
      create: false,
      searchField: ["text"],
      placeholder: el.querySelector("option[value='']")?.textContent || "Select…",
      render: { no_results: () => '<div class="no-results px-3 py-2 text-sm text-slate-400">No match found</div>' },
      onDropdownOpen() { this.dropdown.querySelector(".dropdown-input")?.setAttribute("placeholder", "Type to search…") }
    })
  })
}

const observer = new MutationObserver((muts) => {
  muts.forEach((m) => m.addedNodes.forEach((n) => n.nodeType === 1 && enhance(n)))
})

document.addEventListener("turbo:load", () => {
  enhance(document)
  observer.observe(document.body, { childList: true, subtree: true })
})
