const COORDINATE_INPUT_SELECTOR =
  'astro-island[component-export="FinderApp"] input:is([data-testid="map-goto-x"], [data-testid="map-goto-z"])'

export function suppressCoordinateAutofill(): () => void {
  const originalAutocomplete = new Map<HTMLElement, string | null>()

  const disableAutocomplete = (element: HTMLElement) => {
    if (!originalAutocomplete.has(element)) {
      originalAutocomplete.set(element, element.getAttribute('autocomplete'))
    }
    if (element.getAttribute('autocomplete') !== 'off') {
      element.setAttribute('autocomplete', 'off')
    }
  }

  const syncInputs = () => {
    for (const [element, autocomplete] of originalAutocomplete) {
      if (element.isConnected) continue
      // Detached nodes may be reused, so restore them before forgetting their original values.
      restoreAutocomplete(element, autocomplete)
      originalAutocomplete.delete(element)
    }

    for (const input of document.querySelectorAll<HTMLInputElement>(COORDINATE_INPUT_SELECTOR)) {
      disableAutocomplete(input)
      if (input.form) disableAutocomplete(input.form)
    }
  }

  const observer = new MutationObserver(syncInputs)
  observer.observe(document, {
    childList: true,
    subtree: true,
    attributes: true,
    attributeFilter: ['autocomplete'],
  })
  syncInputs()

  return () => {
    observer.disconnect()
    for (const [element, autocomplete] of originalAutocomplete) {
      restoreAutocomplete(element, autocomplete)
    }
    originalAutocomplete.clear()
  }
}

function restoreAutocomplete(element: HTMLElement, autocomplete: string | null): void {
  if (element.getAttribute('autocomplete') !== 'off') return
  if (autocomplete === null) element.removeAttribute('autocomplete')
  else element.setAttribute('autocomplete', autocomplete)
}
