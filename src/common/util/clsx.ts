export interface ClassDictionary {
  readonly [className: string]: unknown
}

export type ClassArray = readonly ClassValue[]
export type ClassValue =
  ClassArray | ClassDictionary | string | number | bigint | boolean | null | undefined

function resolveClassValue(value: ClassValue): string {
  let result = ''

  if (typeof value === 'string' || typeof value === 'number') {
    result += value
  } else if (typeof value === 'object' && value !== null) {
    if (Array.isArray(value)) {
      for (const item of value) {
        if (!item) continue
        const className = resolveClassValue(item)
        if (!className) continue
        if (result) result += ' '
        result += className
      }
    } else {
      const dictionary = value as ClassDictionary
      for (const className in dictionary) {
        if (!dictionary[className]) continue
        if (result) result += ' '
        result += className
      }
    }
  }

  return result
}

export function clsx(...inputs: ClassValue[]): string {
  let result = ''

  for (const input of inputs) {
    if (!input) continue
    const className = resolveClassValue(input)
    if (!className) continue
    if (result) result += ' '
    result += className
  }

  return result
}

export default clsx
