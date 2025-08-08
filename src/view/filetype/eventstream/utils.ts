import type { IMultiInputItem } from '@/component/MultiInput'

export interface IEventStreamEvent {
  id?: string
  event?: string
  data?: string
  retry?: number
}

export type DisplayMode = 'inline' | 'lines'

export interface IChainPath extends IMultiInputItem {
  path: string
}

export const parseEventStream = (content: string): IEventStreamEvent[] => {
  if (!content) return []

  const events: IEventStreamEvent[] = []
  const lines = content.split('\n')
  let currentEvent: IEventStreamEvent = {}

  for (const line of lines) {
    const trimmedLine = line.trim()

    if (trimmedLine === '') {
      if (Object.keys(currentEvent).length > 0) {
        events.push(currentEvent)
        currentEvent = {}
      }
      continue
    }

    if (trimmedLine.startsWith(':')) continue

    const colonIndex = trimmedLine.indexOf(':')
    if (colonIndex === -1) continue

    const field = trimmedLine.slice(0, colonIndex).trim()
    const value = trimmedLine.slice(colonIndex + 1).trim()

    switch (field) {
      case 'id':
        currentEvent.id = value
        break
      case 'event':
        currentEvent.event = value
        break
      case 'data':
        currentEvent.data = currentEvent.data ? `${currentEvent.data}\n${value}` : value
        break
      case 'retry':
        currentEvent.retry = parseInt(value, 10)
        break
    }
  }

  if (Object.keys(currentEvent).length > 0) {
    events.push(currentEvent)
  }

  return events
}

export const parseJsonData = (data: string): { parsed: unknown; isJson: boolean } => {
  try {
    return { parsed: JSON.parse(data), isJson: true }
  } catch {
    return { parsed: data, isJson: false }
  }
}

export const extractValueFromPath = (obj: unknown, path: string): string => {
  if (!path || !path.trim()) return 'undefined'

  try {
    const cleanPath = path.startsWith('.') ? path.slice(1) : path
    const pathParts = cleanPath.split('.').filter(part => part.length > 0)

    let current = obj
    for (const part of pathParts) {
      if (current == null || typeof current !== 'object') {
        return 'undefined'
      }
      current = (current as Record<string, unknown>)[part]
    }

    if (current === undefined || current === null) {
      return 'undefined'
    }

    return String(current)
  } catch {
    return 'undefined'
  }
}

// Color palette for chainpaths
const COLOR_PALETTE = [
  {
    bg: 'bg-purple-100',
    text: 'text-purple-800',
    darkBg: 'dark:bg-purple-900',
    darkText: 'dark:text-purple-300',
  },
  {
    bg: 'bg-cyan-100',
    text: 'text-cyan-800',
    darkBg: 'dark:bg-cyan-900',
    darkText: 'dark:text-cyan-300',
  },
  {
    bg: 'bg-pink-100',
    text: 'text-pink-800',
    darkBg: 'dark:bg-pink-900',
    darkText: 'dark:text-pink-300',
  },
  {
    bg: 'bg-yellow-100',
    text: 'text-yellow-800',
    darkBg: 'dark:bg-yellow-900',
    darkText: 'dark:text-yellow-300',
  },
  {
    bg: 'bg-indigo-100',
    text: 'text-indigo-800',
    darkBg: 'dark:bg-indigo-900',
    darkText: 'dark:text-indigo-300',
  },
  {
    bg: 'bg-teal-100',
    text: 'text-teal-800',
    darkBg: 'dark:bg-teal-900',
    darkText: 'dark:text-teal-300',
  },
  {
    bg: 'bg-rose-100',
    text: 'text-rose-800',
    darkBg: 'dark:bg-rose-900',
    darkText: 'dark:text-rose-300',
  },
  {
    bg: 'bg-emerald-100',
    text: 'text-emerald-800',
    darkBg: 'dark:bg-emerald-900',
    darkText: 'dark:text-emerald-300',
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
