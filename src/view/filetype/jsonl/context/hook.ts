import { useStateValue } from '@guanghechen/react-viewmodel'
import React from 'react'
import { JsonlViewContextType } from './context'
import type { DisplayMode, IChainPath, ModeEnum } from './types'
import type { JsonlViewViewModel } from './viewmodel'

type JsonlContextType = React.ContextType<typeof JsonlViewContextType>

export const useJsonlViewViewModel = (): JsonlViewViewModel => {
  const context = React.useContext(JsonlViewContextType)
  return context.viewmodel
}

export const useJsonlContext = (): JsonlContextType => {
  return React.useContext(JsonlViewContextType)
}

export const useJsonlState = (): {
  workspace: string | null
  filepath: string
  mode: ModeEnum
  activeRecordIndex: number | null
  expandedRecords: Set<number>
  chainPaths: IChainPath[]
  displayMode: DisplayMode
  records: any[]
} => {
  const viewmodel = useJsonlViewViewModel()
  return {
    workspace: useStateValue(viewmodel.workspace$),
    filepath: useStateValue(viewmodel.filepath$),
    mode: useStateValue(viewmodel.mode$),
    activeRecordIndex: useStateValue(viewmodel.activeRecordIndex$),
    expandedRecords: useStateValue(viewmodel.expandedRecords$),
    chainPaths: useStateValue(viewmodel.chainPaths$),
    displayMode: useStateValue(viewmodel.displayMode$),
    records: [], // This would typically come from processed data
  }
}

export const useJsonlActions = (): {
  setWorkspace: (workspace: string | null | ((prev: string | null) => string | null)) => void
  setFilepath: (filepath: string | ((prev: string) => string)) => void
  setMode: (mode: ModeEnum | ((prev: ModeEnum) => ModeEnum)) => void
  setActiveRecordIndex: (index: number | null | ((prev: number | null) => number | null)) => void
  setExpandedRecords: (records: Set<number> | ((prev: Set<number>) => Set<number>)) => void
  setChainPaths: (paths: IChainPath[] | ((prev: IChainPath[]) => IChainPath[])) => void
  setDisplayMode: (mode: DisplayMode | ((prev: DisplayMode) => DisplayMode)) => void
  toggleAllRecords: () => void
} => {
  const viewmodel = useJsonlViewViewModel()

  const setWorkspace = React.useCallback(
    (workspace: string | null | ((prev: string | null) => string | null)) => {
      const newWorkspace =
        typeof workspace === 'function' ? workspace(viewmodel.workspace$.getSnapshot()) : workspace
      viewmodel.workspace$.next(newWorkspace)
    },
    [viewmodel],
  )

  const setFilepath = React.useCallback(
    (filepath: string | ((prev: string) => string)) => {
      const newFilepath =
        typeof filepath === 'function' ? filepath(viewmodel.filepath$.getSnapshot()) : filepath
      viewmodel.filepath$.next(newFilepath)
    },
    [viewmodel],
  )

  const setMode = React.useCallback(
    (mode: ModeEnum | ((prev: ModeEnum) => ModeEnum)) => {
      const newMode = typeof mode === 'function' ? mode(viewmodel.mode$.getSnapshot()) : mode
      viewmodel.mode$.next(newMode)
    },
    [viewmodel],
  )

  const setActiveRecordIndex = React.useCallback(
    (index: number | null | ((prev: number | null) => number | null)) => {
      const newIndex =
        typeof index === 'function' ? index(viewmodel.activeRecordIndex$.getSnapshot()) : index
      viewmodel.activeRecordIndex$.next(newIndex)
    },
    [viewmodel],
  )

  const setExpandedRecords = React.useCallback(
    (records: Set<number> | ((prev: Set<number>) => Set<number>)) => {
      const newRecords =
        typeof records === 'function' ? records(viewmodel.expandedRecords$.getSnapshot()) : records
      viewmodel.expandedRecords$.next(newRecords)
    },
    [viewmodel],
  )

  const setChainPaths = React.useCallback(
    (paths: IChainPath[] | ((prev: IChainPath[]) => IChainPath[])) => {
      const newPaths =
        typeof paths === 'function' ? paths(viewmodel.chainPaths$.getSnapshot()) : paths
      viewmodel.chainPaths$.next(newPaths)
    },
    [viewmodel],
  )

  const setDisplayMode = React.useCallback(
    (mode: DisplayMode | ((prev: DisplayMode) => DisplayMode)) => {
      const newMode = typeof mode === 'function' ? mode(viewmodel.displayMode$.getSnapshot()) : mode
      viewmodel.displayMode$.next(newMode)
    },
    [viewmodel],
  )

  const toggleAllRecords = React.useCallback(() => {
    // Implementation would toggle all records expand/collapse
  }, [])

  return {
    setWorkspace,
    setFilepath,
    setMode,
    setActiveRecordIndex,
    setExpandedRecords,
    setChainPaths,
    setDisplayMode,
    toggleAllRecords,
  }
}
