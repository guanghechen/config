import type { ExcalidrawElement } from '@excalidraw/excalidraw/element/types'
import { Computed } from '@guanghechen/react-viewmodel'
import React from 'react'
import { toast } from 'react-toastify'
import type { IJsonFileData } from '@/hook/api/file'
import { useFileResult } from '@/hook/useFileResult'
import { useSingleton } from '@/hook/useSingleton'
import type { IExcalidrawViewContext } from './context'
import { ExcalidrawViewContextType } from './context'
import type { IExcalidrawViewData, ModeEnum } from './types'
import { ExcalidrawViewViewModel } from './viewmodel'

const storageKey: string = '#/view/filetype/excalidraw'

interface IProps {
  readonly workspace: string | null
  readonly filepath: string
  readonly filepathDirtyTick: number
  readonly mode?: ModeEnum
  readonly elements?: ReadonlyArray<ExcalidrawElement>
  readonly content?: string | null
  readonly children: React.ReactNode
}

export const ExcalidrawViewProvider: React.FC<IProps> = props => {
  const { workspace, filepath, filepathDirtyTick, mode, elements, content, children } = props
  const viewmodel: ExcalidrawViewViewModel | null = useSingleton<ExcalidrawViewViewModel>(() => {
    const rawViewData: Partial<IExcalidrawViewData> = JSON.parse(
      window.localStorage.getItem(storageKey) || '{}',
    )
    const viewData: IExcalidrawViewData = ExcalidrawViewViewModel.normalize(rawViewData)
    return new ExcalidrawViewViewModel({
      workspace,
      filepath,
      mode: mode ?? viewData.mode,
      elements,
      content,
    })
  })
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
        mode={mode}
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
  readonly mode?: ModeEnum
  readonly elements?: ReadonlyArray<ExcalidrawElement>
  readonly content?: string | null
}

const SideEffect: React.FC<ISideEffectProps> = props => {
  const { viewmodel, workspace, filepath, filepathDirtyTick, mode, elements, content } = props

  usePersistent(viewmodel)
  useSyncProps(viewmodel, workspace, filepath, mode, elements, content)
  useData(viewmodel, workspace, filepath, filepathDirtyTick)

  return <React.Fragment />
}

SideEffect.displayName = 'ExcalidrawViewSideEffect'

// /////////////////////////////////////////////////////////////////////////////////////////////////

const usePersistent = (viewmodel: ExcalidrawViewViewModel): void => {
  React.useEffect(() => {
    const computed = Computed.fromObservables([viewmodel.mode$], () => {
      const data: IExcalidrawViewData = viewmodel.dump()
      window.localStorage.setItem(storageKey, JSON.stringify(data))
    })
    return (): void => {
      computed.dispose()
    }
  }, [viewmodel])
}

const useSyncProps = (
  viewmodel: ExcalidrawViewViewModel,
  workspace: string | null,
  filepath: string,
  mode: ModeEnum | undefined,
  elements: ReadonlyArray<ExcalidrawElement> | undefined,
  content: string | null | undefined,
): void => {
  React.useEffect(() => {
    if (viewmodel.disposed) return
    viewmodel.workspace$.next(workspace)
  }, [viewmodel, workspace])

  React.useEffect(() => {
    if (viewmodel.disposed) return
    viewmodel.filepath$.next(filepath)
  }, [viewmodel, filepath])

  React.useEffect(() => {
    if (viewmodel.disposed) return
    viewmodel.mode$.next(mode ?? viewmodel.mode$.getSnapshot())
  }, [viewmodel, mode])

  React.useEffect(() => {
    if (viewmodel.disposed) return
    viewmodel.elements$.next(elements ?? [])
  }, [viewmodel, elements])

  React.useEffect(() => {
    if (viewmodel.disposed) return
    viewmodel.content$.next(content ?? null)
  }, [viewmodel, content])
}

const useData = (
  viewmodel: ExcalidrawViewViewModel,
  workspace: string | null,
  filepath: string,
  filepathDirtyTick: number,
): void => {
  const { data, error } = useFileResult<IJsonFileData>(workspace, filepath, filepathDirtyTick)

  React.useEffect(() => {
    if (viewmodel.disposed) return

    if (data) {
      viewmodel.data$.next(data)
      viewmodel.content$.next(data.content)
    } else if (error) {
      viewmodel.data$.next(null)
      viewmodel.content$.next(null)
      toast.error(typeof error === 'string' ? error : String(error))
    } else {
      viewmodel.data$.next(null)
      viewmodel.content$.next(null)
    }
  }, [data, error, viewmodel])
}
