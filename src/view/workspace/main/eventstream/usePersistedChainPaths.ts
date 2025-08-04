import React from 'react'

const STORAGE_KEY = 'yozora-eventstream-chain-paths'

export const usePersistedChainPaths = (): [string[], (paths: string[]) => void] => {
  const [chainPaths, setChainPaths] = React.useState<string[]>(() => {
    try {
      const stored = localStorage.getItem(STORAGE_KEY)
      return stored ? JSON.parse(stored) : []
    } catch (error) {
      console.warn('Failed to load chain paths from localStorage:', error)
      return []
    }
  })

  const setPersistedChainPaths = React.useCallback((paths: string[]) => {
    try {
      localStorage.setItem(STORAGE_KEY, JSON.stringify(paths))
      setChainPaths(paths)
    } catch (error) {
      console.warn('Failed to save chain paths to localStorage:', error)
      setChainPaths(paths) // Still update state even if persistence fails
    }
  }, [])

  return [chainPaths, setPersistedChainPaths]
}
