import React from 'react'
import { JsonlViewContextType } from './context'
import type { DisplayMode, IChainPath, ModeEnum } from './types'
import { JsonlViewViewModel } from './viewmodel'

interface IProps {
  readonly workspace: string | null
  readonly filepath: string
  readonly mode?: ModeEnum
  readonly activeRecordIndex?: number | null
  readonly expandedRecords?: Set<number>
  readonly chainPaths?: IChainPath[]
  readonly displayMode?: DisplayMode
  readonly children: React.ReactNode
}

export const JsonlViewProvider: React.FC<IProps> = props => {
  const {
    workspace,
    filepath,
    mode,
    activeRecordIndex,
    expandedRecords,
    chainPaths,
    displayMode,
    children,
  } = props
  const [viewmodel] = React.useState<JsonlViewViewModel>(
    () =>
      new JsonlViewViewModel({
        workspace,
        filepath,
        mode,
        activeRecordIndex,
        expandedRecords,
        chainPaths,
        displayMode,
      }),
  )
  const value = React.useMemo(() => ({ viewmodel }), [viewmodel])

  return (
    <JsonlViewContextType.Provider value={value}>
      {children}
      <SideEffect
        viewmodel={viewmodel}
        workspace={workspace}
        filepath={filepath}
        mode={mode}
        activeRecordIndex={activeRecordIndex}
        expandedRecords={expandedRecords}
        chainPaths={chainPaths}
        displayMode={displayMode}
      />
    </JsonlViewContextType.Provider>
  )
}

JsonlViewProvider.displayName = 'JsonlViewProvider'

// /////////////////////////////////////////////////////////////////////////////////////////////////

interface ISideEffectProps {
  readonly viewmodel: JsonlViewViewModel
  readonly workspace: string | null
  readonly filepath: string
  readonly mode?: ModeEnum
  readonly activeRecordIndex?: number | null
  readonly expandedRecords?: Set<number>
  readonly chainPaths?: IChainPath[]
  readonly displayMode?: DisplayMode
}

const SideEffect: React.FC<ISideEffectProps> = props => {
  const {
    viewmodel,
    workspace,
    filepath,
    mode,
    activeRecordIndex,
    expandedRecords,
    chainPaths,
    displayMode,
  } = props

  React.useEffect(() => {
    viewmodel.workspace$.next(workspace)
  }, [viewmodel.workspace$, workspace])

  React.useEffect(() => {
    viewmodel.filepath$.next(filepath)
  }, [viewmodel.filepath$, filepath])

  React.useEffect(() => {
    viewmodel.mode$.next(mode ?? 1)
  }, [viewmodel.mode$, mode])

  React.useEffect(() => {
    viewmodel.activeRecordIndex$.next(activeRecordIndex ?? null)
  }, [viewmodel.activeRecordIndex$, activeRecordIndex])

  React.useEffect(() => {
    viewmodel.expandedRecords$.next(expandedRecords ?? new Set())
  }, [viewmodel.expandedRecords$, expandedRecords])

  React.useEffect(() => {
    viewmodel.chainPaths$.next(chainPaths ?? [])
  }, [viewmodel.chainPaths$, chainPaths])

  React.useEffect(() => {
    viewmodel.displayMode$.next(displayMode ?? 'lines')
  }, [viewmodel.displayMode$, displayMode])

  return <React.Fragment />
}

SideEffect.displayName = 'JsonlViewSideEffect'
