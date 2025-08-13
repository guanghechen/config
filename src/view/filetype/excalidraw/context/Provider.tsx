import type { ExcalidrawElement } from '@excalidraw/excalidraw/element/types'
import React from 'react'
import { ViewModelCleanupSideEffect } from '@/container/ViewModelCleanup'
import type { SiteTheme } from '@/context/site'
import { useFileResult } from '@/hook/useFileResult'
import type { IJsonFileData } from '@/util/fetch'
import { ExcalidrawViewContextType } from './context'
import { ExcalidrawViewViewModel } from './viewmodel'

interface IProps {
  readonly workspace: string | null
  readonly filepath: string
  readonly filepathDirtyTick: number
  readonly elements?: ReadonlyArray<ExcalidrawElement>
  readonly content?: string | null
  readonly theme?: SiteTheme
  readonly error?: string | null
  readonly children: React.ReactNode
}

export const ExcalidrawViewProvider: React.FC<IProps> = props => {
  const { workspace, filepath, filepathDirtyTick, elements, content, theme, error, children } =
    props
  const [viewmodel] = React.useState<ExcalidrawViewViewModel>(
    () => new ExcalidrawViewViewModel({ elements, content, workspace, filepath, theme, error }),
  )
  const value = React.useMemo(() => ({ viewmodel }), [viewmodel])

  return (
    <React.Fragment>
      <ExcalidrawViewContextType.Provider value={value}>
        {children}
      </ExcalidrawViewContextType.Provider>
      <SideEffect
        viewmodel={viewmodel}
        workspace={workspace}
        filepath={filepath}
        filepathDirtyTick={filepathDirtyTick}
        elements={elements}
        content={content}
        theme={theme}
        error={error}
      />
      <ViewModelCleanupSideEffect viewmodel={viewmodel} />
    </React.Fragment>
  )
}

ExcalidrawViewProvider.displayName = 'ExcalidrawViewProvider'

// /////////////////////////////////////////////////////////////////////////////////////////////////

interface ISideEffectProps {
  readonly viewmodel: ExcalidrawViewViewModel
  readonly workspace: string | null
  readonly filepath: string
  readonly filepathDirtyTick: number
  readonly elements?: ReadonlyArray<ExcalidrawElement>
  readonly content?: string | null
  readonly theme?: SiteTheme
  readonly error?: string | null
}

const SideEffect: React.FC<ISideEffectProps> = props => {
  const { viewmodel, workspace, filepath, filepathDirtyTick, elements, theme, error } = props

  const { data, error: fileError } = useFileResult<IJsonFileData>(
    workspace,
    filepath,
    filepathDirtyTick,
  )

  React.useEffect(() => {
    if (viewmodel.disposed) return

    const combinedError = error || fileError
    if (data) {
      viewmodel.data$.next(data)
      viewmodel.content$.next(data.content)
      viewmodel.error$.next(combinedError ? String(combinedError) : null)
    } else if (combinedError) {
      viewmodel.data$.next(null)
      viewmodel.content$.next(null)
      viewmodel.error$.next(
        typeof combinedError === 'string' ? combinedError : String(combinedError),
      )
    } else {
      viewmodel.data$.next(null)
      viewmodel.content$.next(null)
      viewmodel.error$.next(null)
    }
  }, [data, fileError, error, viewmodel])

  React.useEffect(() => {
    if (viewmodel.disposed) return
    viewmodel.elements$.next(elements ?? [])
  }, [viewmodel.elements$, elements])

  React.useEffect(() => {
    if (viewmodel.disposed) return
    viewmodel.workspace$.next(workspace ?? null)
  }, [viewmodel.workspace$, workspace])

  React.useEffect(() => {
    if (viewmodel.disposed) return
    viewmodel.filepath$.next(filepath ?? null)
  }, [viewmodel.filepath$, filepath])

  React.useEffect(() => {
    if (viewmodel.disposed) return
    viewmodel.theme$.next(theme ?? null)
  }, [viewmodel.theme$, theme])

  return <React.Fragment />
}

SideEffect.displayName = 'ExcalidrawViewSideEffect'
