import React from 'react'

const STORAGE_KEY = 'yozora-eventstream-chain-paths'
const DISPLAY_MODE_KEY = 'yozora-eventstream-display-mode'

export type DisplayMode = 'inline' | 'lines'

interface IPersistedState {
  paths: string[]
  displayMode: DisplayMode
}

export const usePersistedChainPaths = (): [
  string[],
  (paths: string[]) => void,
  DisplayMode,
  (mode: DisplayMode) => void
] => {
  const [state, setState] = React.useState<IPersistedState>(() => {
    try {
      const storedPaths = localStorage.getItem(STORAGE_KEY)
      const storedDisplayMode = localStorage.getItem(DISPLAY_MODE_KEY)
      
      return {
        paths: storedPaths ? JSON.parse(storedPaths) : [],
        displayMode: storedDisplayMode ? JSON.parse(storedDisplayMode) : 'inline'
      }
    } catch (error) {
      console.warn('Failed to load chain paths from localStorage:', error)
      return {
        paths: [],
        displayMode: 'inline'
      }
    }
  })

  const setPersistedChainPaths = React.useCallback((paths: string[]) => {
    try {
      localStorage.setItem(STORAGE_KEY, JSON.stringify(paths))
      setState(prev => ({ ...prev, paths }))
    } catch (error) {
      console.warn('Failed to save chain paths to localStorage:', error)
      setState(prev => ({ ...prev, paths })) // Still update state even if persistence fails
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

  return [state.paths, setPersistedChainPaths, state.displayMode, setPersistedDisplayMode]
}
