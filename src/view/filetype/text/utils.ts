// Color palette for chainpaths
// Chain path conversion utilities
import type { IChainPath } from './context'

// NIL symbol to represent null/undefined values, distinct from strings that contain "nil"
export const NIL_SYMBOL: symbol = Symbol('NIL')
export type NILSymbol = typeof NIL_SYMBOL

const COLOR_PALETTE = [
  {
    bg: 'bg-purple-100',
    text: 'text-purple-800',
    darkBg: 'dark:bg-purple-800',
    darkText: 'dark:text-purple-200',
  },
  {
    bg: 'bg-cyan-100',
    text: 'text-cyan-800',
    darkBg: 'dark:bg-cyan-800',
    darkText: 'dark:text-cyan-200',
  },
  {
    bg: 'bg-pink-100',
    text: 'text-pink-800',
    darkBg: 'dark:bg-pink-800',
    darkText: 'dark:text-pink-200',
  },
  {
    bg: 'bg-yellow-100',
    text: 'text-yellow-800',
    darkBg: 'dark:bg-yellow-800',
    darkText: 'dark:text-yellow-200',
  },
  {
    bg: 'bg-green-100',
    text: 'text-green-800',
    darkBg: 'dark:bg-green-800',
    darkText: 'dark:text-green-200',
  },
  {
    bg: 'bg-blue-100',
    text: 'text-blue-800',
    darkBg: 'dark:bg-blue-800',
    darkText: 'dark:text-blue-200',
  },
  {
    bg: 'bg-indigo-100',
    text: 'text-indigo-800',
    darkBg: 'dark:bg-indigo-800',
    darkText: 'dark:text-indigo-200',
  },
  {
    bg: 'bg-red-100',
    text: 'text-red-800',
    darkBg: 'dark:bg-red-800',
    darkText: 'dark:text-red-200',
  },
  {
    bg: 'bg-orange-100',
    text: 'text-orange-800',
    darkBg: 'dark:bg-orange-800',
    darkText: 'dark:text-orange-200',
  },
  {
    bg: 'bg-emerald-100',
    text: 'text-emerald-800',
    darkBg: 'dark:bg-emerald-800',
    darkText: 'dark:text-emerald-200',
  },
  {
    bg: 'bg-violet-100',
    text: 'text-violet-800',
    darkBg: 'dark:bg-violet-800',
    darkText: 'dark:text-violet-200',
  },
  {
    bg: 'bg-rose-100',
    text: 'text-rose-800',
    darkBg: 'dark:bg-rose-800',
    darkText: 'dark:text-rose-200',
  },
] as const

export interface IPathColor {
  bg: string
  text: string
  darkBg: string
  darkText: string
}

export const getPathColor = (path: string, allPaths: string[]): IPathColor => {
  const index = allPaths.indexOf(path)
  if (index === -1) return COLOR_PALETTE[0]
  return COLOR_PALETTE[index % COLOR_PALETTE.length]
}

export const getPathColorClasses = (path: string, allPaths: string[]): string => {
  const color = getPathColor(path, allPaths)
  return `${color.bg} ${color.text} ${color.darkBg} ${color.darkText}`
}

export const createChainPath = (value: string): IChainPath => {
  const isInvisible = value.startsWith('!')
  return {
    path: isInvisible ? value.slice(1) : value,
    value,
    visible: !isInvisible,
  }
}

export const stringArrayToChainPaths = (paths: string[] | undefined): IChainPath[] => {
  return Array.isArray(paths) ? paths.map(createChainPath) : []
}

export const chainPathsToStringArray = (chainPaths: IChainPath[]): string[] => {
  return chainPaths.map(cp => (cp.visible ? cp.path : `!${cp.path}`))
}

export const toggleChainPathVisibility = (chainPath: IChainPath): IChainPath => {
  const newVisible = !chainPath.visible
  const newValue =
    newVisible && chainPath.value.startsWith('!')
      ? chainPath.value.slice(1)
      : !newVisible && !chainPath.value.startsWith('!')
        ? `!${chainPath.value}`
        : chainPath.value

  return {
    ...chainPath,
    visible: newVisible,
    value: newValue,
    path: newValue.startsWith('!') ? newValue.slice(1) : newValue,
  }
}

export const extractValueFromPath = (obj: unknown, path: string): string | NILSymbol => {
  if (!path || !path.trim()) return NIL_SYMBOL

  try {
    const cleanPath = path.startsWith('.') ? path.slice(1) : path
    const pathParts = cleanPath.split('.').filter(part => part.length > 0)

    let current = obj
    for (const part of pathParts) {
      if (current == null || typeof current !== 'object') {
        return NIL_SYMBOL
      }
      current = (current as Record<string, unknown>)[part]
    }

    if (current === undefined || current === null) {
      return NIL_SYMBOL
    }

    return String(current)
  } catch {
    return NIL_SYMBOL
  }
}

export const isNilValue = (value: string | symbol): boolean => {
  return value === NIL_SYMBOL
}

export const displayValue = (value: string | symbol): string => {
  return value === NIL_SYMBOL ? 'nil' : (value as string)
}

export const getDarkerPathColorClasses = (path: string, allPaths: string[]): string => {
  const color = getPathColor(path, allPaths)
  // Extract the color name from the background class (e.g., 'bg-purple-100' -> 'purple')
  const colorMatch = color.bg.match(/bg-(\w+)-\d+/)
  const colorName = colorMatch ? colorMatch[1] : 'gray'

  // Return darker variants with reduced opacity and border
  return `bg-${colorName}-200/40 text-${colorName}-900 dark:bg-${colorName}-700/40 dark:text-${colorName}-300 border border-${colorName}-300/60 dark:border-${colorName}-500/60 opacity-75`
}
