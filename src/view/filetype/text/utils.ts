// Color palette for chainpaths
// Chain path conversion utilities
import type { IChainPath } from './context'

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

export const stringArrayToChainPaths = (paths: string[] | undefined): IChainPath[] => {
  if (!Array.isArray(paths)) return []
  return paths.map(path => ({
    path,
    value: path,
    visible: true,
  }))
}

export const chainPathsToStringArray = (chainPaths: IChainPath[]): string[] => {
  return chainPaths.map(cp => cp.path)
}

export const sortChainPaths = (chainPaths: IChainPath[]): IChainPath[] => {
  return [...chainPaths].sort((a, b) => a.path.localeCompare(b.path))
}

export const extractValueFromPath = (obj: unknown, path: string): string => {
  if (!path || !path.trim()) return 'nil'

  try {
    const cleanPath = path.startsWith('.') ? path.slice(1) : path
    const pathParts = cleanPath.split('.').filter(part => part.length > 0)

    let current = obj
    for (const part of pathParts) {
      if (current == null || typeof current !== 'object') {
        return 'nil'
      }
      current = (current as Record<string, unknown>)[part]
    }

    if (current === undefined || current === null) {
      return 'nil'
    }

    return String(current)
  } catch {
    return 'nil'
  }
}
