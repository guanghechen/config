import { Computed } from '@guanghechen/react-viewmodel'
import React from 'react'
import { toast } from 'react-toastify'
import type { IMarkdownFileData } from '@/hook/api/file'
import { useFileResult } from '@/hook/useFileResult'
import { useSingleton } from '@/hook/useSingleton'
import type { IMarkdownViewContext } from './context'
import { MarkdownViewContextType } from './context'
import type { IMarkdownViewData, ModeEnum } from './types'
import { MarkdownViewViewModel } from './viewmodel'

const storageKey: string = '#/view/filetype/markdown'

interface IProps {
  readonly workspace: string | null
  readonly filepath: string
  readonly filepathDirtyTick: number
  readonly mode?: ModeEnum
  readonly children: React.ReactNode
}

export const MarkdownViewProvider: React.FC<IProps> = props => {
  const { workspace, filepath, filepathDirtyTick, mode, children } = props
  const viewmodel: MarkdownViewViewModel | null = useSingleton<MarkdownViewViewModel>(() => {
    const rawViewData: Partial<IMarkdownViewData> = JSON.parse(
      window.localStorage.getItem(storageKey) || '{}',
    )
    const viewData: IMarkdownViewData = MarkdownViewViewModel.normalize(rawViewData)
    return new MarkdownViewViewModel({
      workspace,
      filepath,
      mode: mode ?? viewData.mode,
    })
  })
  const context: IMarkdownViewContext | null = React.useMemo<IMarkdownViewContext | null>(
    () => (viewmodel ? { viewmodel } : null),
    [viewmodel],
  )

  if (!viewmodel || !context) return <React.Fragment />

  return (
    <React.Fragment>
      <MarkdownViewContextType.Provider value={context}>
        {children}
      </MarkdownViewContextType.Provider>
      <SideEffect
        viewmodel={viewmodel}
        workspace={workspace}
        filepath={filepath}
        filepathDirtyTick={filepathDirtyTick}
        mode={mode}
      />
    </React.Fragment>
  )
}

MarkdownViewProvider.displayName = 'MarkdownViewProvider'

// /////////////////////////////////////////////////////////////////////////////////////////////////

interface ISideEffectProps {
  readonly viewmodel: MarkdownViewViewModel
  readonly workspace: string | null
  readonly filepath: string
  readonly filepathDirtyTick: number
  readonly mode?: ModeEnum
}

const SideEffect: React.FC<ISideEffectProps> = props => {
  const { viewmodel, workspace, filepath, filepathDirtyTick, mode } = props

  usePersistent(viewmodel)
  useSyncProps(viewmodel, workspace, filepath, mode)
  useData(viewmodel, workspace, filepath, filepathDirtyTick)

  return <React.Fragment />
}

SideEffect.displayName = 'MarkdownViewSideEffect'

// /////////////////////////////////////////////////////////////////////////////////////////////////

const usePersistent = (viewmodel: MarkdownViewViewModel): void => {
  React.useEffect(() => {
    const computed = Computed.fromObservables([viewmodel.mode$], () => {
      const data: IMarkdownViewData = viewmodel.dump()
      window.localStorage.setItem(storageKey, JSON.stringify(data))
    })
    return (): void => {
      computed.dispose()
    }
  }, [viewmodel])
}

const useSyncProps = (
  viewmodel: MarkdownViewViewModel,
  workspace: string | null,
  filepath: string,
  mode: ModeEnum | undefined,
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
}

const useData = (
  viewmodel: MarkdownViewViewModel,
  workspace: string | null,
  filepath: string,
  filepathDirtyTick: number,
): void => {
  const { data, error } = useFileResult<IMarkdownFileData>(workspace, filepath, filepathDirtyTick)

  React.useEffect(() => {
    if (viewmodel.disposed) return

    if (data) {
      viewmodel.data$.next(data)
    } else if (error) {
      viewmodel.data$.next(null)
      toast.error(typeof error === 'string' ? error : String(error))
    } else {
      viewmodel.data$.next(null)
    }
  }, [data, error, viewmodel])
}
