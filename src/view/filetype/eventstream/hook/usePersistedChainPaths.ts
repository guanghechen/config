import React from 'react'
import type { DisplayMode, IChainPath } from '../utils'

export type { DisplayMode, IChainPath }

const STORAGE_KEY = 'yozora-eventstream-chain-paths'
const DISPLAY_MODE_KEY = 'yozora-eventstream-display-mode'

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
            chainPaths = parsed.map(path => ({ path, value: path, visible: true }))
          } else {
            // New format - ensure backward compatibility
            chainPaths = parsed.map(item => ({
              path: item.path || item.value,
              value: item.path || item.value,
              visible: item.visible,
            }))
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

  // Listen for storage changes to sync state across components/tabs
  React.useEffect(() => {
    const handleStorageChange = (e: StorageEvent): void => {
      if (e.key === STORAGE_KEY && e.newValue) {
        try {
          const parsed = JSON.parse(e.newValue)
          let chainPaths: IChainPath[] = []
          if (Array.isArray(parsed) && parsed.length > 0) {
            if (typeof parsed[0] === 'string') {
              chainPaths = parsed.map(path => ({ path, value: path, visible: true }))
            } else {
              chainPaths = parsed.map(item => ({
                path: item.path || item.value,
                value: item.path || item.value,
                visible: item.visible,
              }))
            }
          }
          setState(prev => ({ ...prev, chainPaths }))
        } catch (error) {
          console.warn('Failed to parse storage change for chain paths:', error)
        }
      } else if (e.key === DISPLAY_MODE_KEY && e.newValue) {
        try {
          const displayMode = JSON.parse(e.newValue)
          setState(prev => ({ ...prev, displayMode }))
        } catch (error) {
          console.warn('Failed to parse storage change for display mode:', error)
        }
      }
    }

    window.addEventListener('storage', handleStorageChange)
    return () => window.removeEventListener('storage', handleStorageChange)
  }, [])

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
