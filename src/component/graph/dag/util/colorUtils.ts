export const lightenColor = (color: string, amount: number = 20): string => {
  const hex = color.replace('#', '')
  const r = Math.min(255, parseInt(hex.substring(0, 2), 16) + amount)
  const g = Math.min(255, parseInt(hex.substring(2, 4), 16) + amount)
  const b = Math.min(255, parseInt(hex.substring(4, 6), 16) + amount)

  return `#${r.toString(16).padStart(2, '0')}${g.toString(16).padStart(2, '0')}${b.toString(16).padStart(2, '0')}`
}

export const darkenColor = (color: string, amount: number = 20): string => {
  const hex = color.replace('#', '')
  const r = Math.max(0, parseInt(hex.substring(0, 2), 16) - amount)
  const g = Math.max(0, parseInt(hex.substring(2, 4), 16) - amount)
  const b = Math.max(0, parseInt(hex.substring(4, 6), 16) - amount)

  return `#${r.toString(16).padStart(2, '0')}${g.toString(16).padStart(2, '0')}${b.toString(16).padStart(2, '0')}`
}

export const hexToRgba = (hex: string, alpha: number = 1): string => {
  const cleanHex = hex.replace('#', '')
  const r = parseInt(cleanHex.substring(0, 2), 16)
  const g = parseInt(cleanHex.substring(2, 4), 16)
  const b = parseInt(cleanHex.substring(4, 6), 16)

  return `rgba(${r}, ${g}, ${b}, ${alpha})`
}
