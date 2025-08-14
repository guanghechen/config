import { Computed } from '@guanghechen/react-viewmodel'
import React from 'react'
import { useFileResult } from '@/hook/useFileResult'
import { useSingleton } from '@/hook/useSingleton'
import type { IHtmlFileData } from '@/util/fetch'
import type { IHtmlViewContext } from './context'
import { HtmlViewContextType } from './context'
import type { IHtmlViewData, ModeEnum } from './types'
import { HtmlViewViewModel } from './viewmodel'

const storageKey: string = '#/view/filetype/html'

interface IProps {
  readonly workspace: string | null
  readonly filepath: string | null
  readonly filepathDirtyTick: number
  readonly mode?: ModeEnum
  readonly children: React.ReactNode
}

export const HtmlViewProvider: React.FC<IProps> = props => {
  const { workspace, filepath, filepathDirtyTick, mode, children } = props
  const viewmodel: HtmlViewViewModel | null = useSingleton<HtmlViewViewModel>(() => {
    const initialData: Partial<IHtmlViewData> = JSON.parse(
      window.localStorage.getItem(storageKey) || '{}',
    )
    return HtmlViewViewModel.fromData({
      mode: mode ?? initialData.mode,
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
      />
    </React.Fragment>
  )
}

HtmlViewProvider.displayName = 'HtmlViewProvider'

// /////////////////////////////////////////////////////////////////////////////////////////////////

interface ISideEffectProps {
  readonly viewmodel: HtmlViewViewModel
  readonly workspace: string | null
  readonly filepath: string | null
  readonly filepathDirtyTick: number
  readonly mode?: ModeEnum
}

const SideEffect: React.FC<ISideEffectProps> = props => {
  const { viewmodel, workspace, filepath, filepathDirtyTick, mode } = props

  const { data, error } = useFileResult<IHtmlFileData>(workspace, filepath, filepathDirtyTick)

  React.useEffect(() => {
    if (viewmodel.disposed) return

    if (data) {
      viewmodel.data$.next(data)
      viewmodel.error$.next(null)
    } else if (error) {
      viewmodel.data$.next(null)
      viewmodel.error$.next(typeof error === 'string' ? error : String(error))
    } else {
      viewmodel.data$.next(null)
      viewmodel.error$.next(null)
    }
  }, [data, error, viewmodel])

  React.useEffect(() => {
    const computed = Computed.fromObservables([viewmodel.mode$], () => {
      const data: IHtmlViewData = viewmodel.dump()
      window.localStorage.setItem(storageKey, JSON.stringify(data))
    })
    return (): void => {
      computed.dispose()
    }
  }, [viewmodel])

  React.useEffect(() => {
    if (viewmodel.disposed) return
    viewmodel.workspace$.next(workspace ?? null)
  }, [viewmodel, workspace])

  React.useEffect(() => {
    if (viewmodel.disposed) return
    viewmodel.filepath$.next(filepath ?? null)
  }, [viewmodel, filepath])

  React.useEffect(() => {
    if (viewmodel.disposed) return
    viewmodel.mode$.next(mode ?? viewmodel.mode$.getSnapshot())
  }, [viewmodel, mode])

  return <React.Fragment />
}

SideEffect.displayName = 'HtmlViewSideEffect'
