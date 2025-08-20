import { Computed } from '@guanghechen/react-viewmodel'
import React from 'react'
import { toast } from 'react-toastify'
import type { IHtmlFileData } from '@/hook/api/file'
import { useFileResult } from '@/hook/useFileResult'
import { useSingleton } from '@/hook/useSingleton'
import type { IHtmlViewContext } from './context'
import { HtmlViewContextType } from './context'
import type { IHtmlViewData, ModeEnum } from './types'
import { HtmlViewViewModel } from './viewmodel'

const storageKey: string = '#/view/filetype/html'

interface IProps {
  readonly workspace: string | null
  readonly filepath: string
  readonly filepathDirtyTick: number
  readonly mode?: ModeEnum
  readonly enableTailwindcss?: boolean
  readonly children: React.ReactNode
}

export const HtmlViewProvider: React.FC<IProps> = props => {
  const { workspace, filepath, filepathDirtyTick, mode, enableTailwindcss, children } = props
  const viewmodel: HtmlViewViewModel | null = useSingleton<HtmlViewViewModel>(() => {
    const rawViewData: Partial<IHtmlViewData> = JSON.parse(
      window.localStorage.getItem(storageKey) || '{}',
    )
    const viewData: IHtmlViewData = HtmlViewViewModel.normalize(rawViewData)
    return new HtmlViewViewModel({
      workspace,
      filepath,
      mode: mode ?? viewData.mode,
      enableTailwindcss: enableTailwindcss ?? viewData.enableTailwindcss,
    })
  })
  const context: IHtmlViewContext | null = React.useMemo<IHtmlViewContext | null>(
    () => (viewmodel ? { viewmodel } : null),
    [viewmodel],
  )

  if (!viewmodel || !context) return <React.Fragment />

  return (
    <React.Fragment>
      <HtmlViewContextType.Provider value={context}>{children}</HtmlViewContextType.Provider>
      <SideEffect
        viewmodel={viewmodel}
        workspace={workspace}
        filepath={filepath}
        filepathDirtyTick={filepathDirtyTick}
        mode={mode}
        enableTailwindcss={enableTailwindcss}
      />
    </React.Fragment>
  )
}

HtmlViewProvider.displayName = 'HtmlViewProvider'

// /////////////////////////////////////////////////////////////////////////////////////////////////

interface ISideEffectProps {
  readonly viewmodel: HtmlViewViewModel
  readonly workspace: string | null
  readonly filepath: string
  readonly filepathDirtyTick: number
  readonly mode?: ModeEnum
  readonly enableTailwindcss?: boolean
}

const SideEffect: React.FC<ISideEffectProps> = props => {
  const { viewmodel, workspace, filepath, filepathDirtyTick, mode, enableTailwindcss } = props

  usePersistent(viewmodel)
  useSyncProps(viewmodel, workspace, filepath, mode, enableTailwindcss)
  useData(viewmodel, workspace, filepath, filepathDirtyTick)

  return <React.Fragment />
}

SideEffect.displayName = 'HtmlViewSideEffect'

// /////////////////////////////////////////////////////////////////////////////////////////////////

const usePersistent = (viewmodel: HtmlViewViewModel): void => {
  React.useEffect(() => {
    const computed = Computed.fromObservables(
      [viewmodel.mode$, viewmodel.enableTailwindcss$],
      () => {
        const data: IHtmlViewData = viewmodel.dump()
        window.localStorage.setItem(storageKey, JSON.stringify(data))
      },
    )
    return (): void => {
      computed.dispose()
    }
  }, [viewmodel])
}

const useSyncProps = (
  viewmodel: HtmlViewViewModel,
  workspace: string | null,
  filepath: string,
  mode: ModeEnum | undefined,
  enableTailwindcss: boolean | undefined,
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
    viewmodel.enableTailwindcss$.next(
      enableTailwindcss ?? viewmodel.enableTailwindcss$.getSnapshot(),
    )
  }, [viewmodel, enableTailwindcss])
}

const useData = (
  viewmodel: HtmlViewViewModel,
  workspace: string | null,
  filepath: string,
  filepathDirtyTick: number,
): void => {
  const { data, error } = useFileResult<IHtmlFileData>(workspace, filepath, filepathDirtyTick)

  React.useEffect(() => {
    if (viewmodel.disposed) return

    if (data) {
      viewmodel.content$.next(data.content)
    } else if (error) {
      viewmodel.content$.next(null)
      toast.error(typeof error === 'string' ? error : String(error))
    } else {
      viewmodel.content$.next(null)
    }
  }, [data, error, viewmodel])
}
