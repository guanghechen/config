import { Computed } from '@guanghechen/react-viewmodel'
import React from 'react'
import { useFileResult } from '@/hook/useFileResult'
import type { IHtmlFileData } from '@/util/fetch'
import { HtmlViewContextType } from './context'
import type { IHtmlViewData } from './types'
import { HtmlViewViewModel } from './viewmodel'

const storageKey: string = '#/view/filetype/html'

interface IProps {
  readonly workspace: string | null
  readonly filepath: string | null
  readonly filepathDirtyTick: number
  readonly tailwindEnabled?: boolean
  readonly children: React.ReactNode
}

export const HtmlViewProvider: React.FC<IProps> = props => {
  const { workspace, filepath, filepathDirtyTick, tailwindEnabled, children } = props
  const [viewmodel] = React.useState<HtmlViewViewModel>(() => {
    const initialData: Partial<IHtmlViewData> = JSON.parse(
      window.localStorage.getItem(storageKey) || '{}',
    )
    return HtmlViewViewModel.fromData({
      tailwindEnabled: tailwindEnabled ?? initialData.tailwindEnabled,
    })
  })
  const value = React.useMemo(() => ({ viewmodel }), [viewmodel])

  return (
    <React.Fragment>
      <HtmlViewContextType.Provider value={value}>{children}</HtmlViewContextType.Provider>
      <SideEffect
        viewmodel={viewmodel}
        workspace={workspace}
        filepath={filepath}
        filepathDirtyTick={filepathDirtyTick}
        tailwindEnabled={tailwindEnabled}
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
  readonly tailwindEnabled?: boolean
}

const SideEffect: React.FC<ISideEffectProps> = props => {
  const { viewmodel, workspace, filepath, filepathDirtyTick, tailwindEnabled } = props

  const { data, error } = useFileResult<IHtmlFileData>(workspace, filepath, filepathDirtyTick)

  React.useEffect(() => {
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
    const computed = Computed.fromObservables([viewmodel.tailwindEnabled$], () => {
      const data: IHtmlViewData = viewmodel.dump()
      window.localStorage.setItem(storageKey, JSON.stringify(data))
    })
    return (): void => {
      computed.dispose()
    }
  }, [viewmodel])

  React.useEffect(() => {
    viewmodel.workspace$.next(workspace ?? null)
  }, [viewmodel.workspace$, workspace])

  React.useEffect(() => {
    viewmodel.filepath$.next(filepath ?? null)
  }, [viewmodel.filepath$, filepath])

  React.useEffect(() => {
    viewmodel.tailwindEnabled$.next(tailwindEnabled ?? viewmodel.tailwindEnabled$.getSnapshot())
  }, [viewmodel.tailwindEnabled$, tailwindEnabled])

  return <React.Fragment />
}

SideEffect.displayName = 'HtmlViewSideEffect'
