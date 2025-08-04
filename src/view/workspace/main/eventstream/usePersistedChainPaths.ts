import React from 'react'

const STORAGE_KEY = 'yozora-eventstream-chain-paths'
const DISPLAY_MODE_KEY = 'yozora-eventstream-display-mode'

export type DisplayMode = 'inline' | 'lines'

export interface IChainPath {
  path: string
  visible: boolean
}

interface IPersistedState {
  chainPaths: IChainPath[]
  displayMode: DisplayMode
}

export const usePersistedChainPaths = (): [
  IChainPath[],
  (chainPaths: IChainPath[]) => void,
  DisplayMode,
  (mode: DisplayMode) => void,
] => {
  const [state, setState] = React.useState<IPersistedState>(() => {
    try {
      const storedPaths = localStorage.getItem(STORAGE_KEY)
      const storedDisplayMode = localStorage.getItem(DISPLAY_MODE_KEY)

      let chainPaths: IChainPath[] = []
      if (storedPaths) {
        const parsed = JSON.parse(storedPaths)
        // Handle legacy format (array of strings) and migrate to new format
        if (Array.isArray(parsed) && parsed.length > 0) {
          if (typeof parsed[0] === 'string') {
            // Legacy format - convert to new format
            chainPaths = parsed.map(path => ({ path, visible: true }))
          } else {
            // New format
            chainPaths = parsed
          }
        }
      }

      return {
        chainPaths,
        displayMode: storedDisplayMode ? JSON.parse(storedDisplayMode) : 'inline',
      }
    } catch (error) {
      console.warn('Failed to load chain paths from localStorage:', error)
      return {
        chainPaths: [],
        displayMode: 'inline',
      }
    }
  })

  const setPersistedChainPaths = React.useCallback((chainPaths: IChainPath[]) => {
    try {
      localStorage.setItem(STORAGE_KEY, JSON.stringify(chainPaths))
      setState(prev => ({ ...prev, chainPaths }))
    } catch (error) {
      console.warn('Failed to save chain paths to localStorage:', error)
      setState(prev => ({ ...prev, chainPaths })) // Still update state even if persistence fails
    }
  }, [])

  const setPersistedDisplayMode = React.useCallback((displayMode: DisplayMode) => {
    try {
      localStorage.setItem(DISPLAY_MODE_KEY, JSON.stringify(displayMode))
      setState(prev => ({ ...prev, displayMode }))
    } catch (error) {
      console.warn('Failed to save display mode to localStorage:', error)
      setState(prev => ({ ...prev, displayMode })) // Still update state even if persistence fails
    }
  }, [])

  return [state.chainPaths, setPersistedChainPaths, state.displayMode, setPersistedDisplayMode]
}
