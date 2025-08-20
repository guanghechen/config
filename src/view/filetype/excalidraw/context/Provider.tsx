import type { ExcalidrawElement } from '@excalidraw/excalidraw/element/types'
import React from 'react'
import { toast } from 'react-toastify'
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
  readonly children: React.ReactNode
}

export const ExcalidrawViewProvider: React.FC<IProps> = props => {
  const { workspace, filepath, filepathDirtyTick, elements, content, children } = props
  const viewmodel: ExcalidrawViewViewModel | null = useSingleton<ExcalidrawViewViewModel>(
    () => new ExcalidrawViewViewModel({ elements, content, filepath }),
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
}

const SideEffect: React.FC<ISideEffectProps> = props => {
  const { viewmodel, workspace, filepath, filepathDirtyTick, elements } = props

  const { data, error: fileError } = useFileResult<IJsonFileData>(
    workspace,
    filepath,
    filepathDirtyTick,
  )

  React.useEffect(() => {
    if (viewmodel.disposed) return

    if (data) {
      viewmodel.data$.next(data)
      viewmodel.content$.next(data.content)
    } else if (fileError) {
      viewmodel.data$.next(null)
      viewmodel.content$.next(null)
      toast.error(typeof fileError === 'string' ? fileError : String(fileError))
    } else {
      viewmodel.data$.next(null)
      viewmodel.content$.next(null)
    }
  }, [data, fileError, viewmodel])

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
