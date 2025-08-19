import type { ExcalidrawElement } from '@excalidraw/excalidraw/element/types'
import React from 'react'
import type { IJsonFileData } from '@/hook/api/file'
import { useFileResult } from '@/hook/useFileResult'
import { useSingleton } from '@/hook/useSingleton'
import type { IExcalidrawViewContext } from './context'
import { ExcalidrawViewContextType } from './context'
import type { ModeEnum } from './types'
import { ExcalidrawViewViewModel } from './viewmodel'

interface IProps {
  readonly workspace: string | null
  readonly filepath: string
  readonly filepathDirtyTick: number
  readonly elements?: ReadonlyArray<ExcalidrawElement>
  readonly content?: string | null
  readonly mode?: ModeEnum
  readonly error?: string | null
  readonly children: React.ReactNode
}

export const ExcalidrawViewProvider: React.FC<IProps> = props => {
  const { workspace, filepath, filepathDirtyTick, elements, content, error, children } = props
  const viewmodel: ExcalidrawViewViewModel | null = useSingleton<ExcalidrawViewViewModel>(
    () => new ExcalidrawViewViewModel({ elements, content, filepath, error }),
  )
  const context: IExcalidrawViewContext | null = React.useMemo<IExcalidrawViewContext | null>(
    () => (viewmodel ? { viewmodel } : null),
    [viewmodel],
  )

  if (!viewmodel || !context) return <React.Fragment />

  return (
    <React.Fragment>
      <ExcalidrawViewContextType.Provider value={context}>
        {children}
      </ExcalidrawViewContextType.Provider>
      <SideEffect
        viewmodel={viewmodel}
        workspace={workspace}
        filepath={filepath}
        filepathDirtyTick={filepathDirtyTick}
        elements={elements}
        content={content}
        error={error}
      />
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
  readonly error?: string | null
}

const SideEffect: React.FC<ISideEffectProps> = props => {
  const { viewmodel, workspace, filepath, filepathDirtyTick, elements, error } = props

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
  }, [viewmodel, elements])

  React.useEffect(() => {
    if (viewmodel.disposed) return
    viewmodel.filepath$.next(filepath ?? null)
  }, [viewmodel, filepath])

  return <React.Fragment />
}

SideEffect.displayName = 'ExcalidrawViewSideEffect'
