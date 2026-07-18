const MAX_SELECTOR_LENGTH = 256
const SAFE_SELECTOR_CHARACTERS = /^[A-Za-z0-9_#.,>\s-]+$/

export function isSafeDomSelector(selector: string): boolean {
  const value = selector.trim()
  return (
    value.length > 0 &&
    value.length <= MAX_SELECTOR_LENGTH &&
    SAFE_SELECTOR_CHARACTERS.test(value) &&
    !value.includes('*') &&
    value.split(',').every(part => part.trim().length > 0)
  )
}
