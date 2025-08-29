import { useViewModel } from '@guanghechen/react-viewmodel'
import React from 'react'
import { usePersist } from '@/hook/usePersist'
import type { IPdfViewContext } from './context'
import { PdfViewContextType } from './context'
import type { IPdfViewData, ModeEnum } from './types'
import { PdfViewViewModel } from './viewmodel'

interface IProps {
  readonly url: string | null
  readonly mode?: ModeEnum
  readonly scale?: number
  readonly multiview?: boolean
  readonly storageKeyScope: string
  readonly children: React.ReactNode
}

export const PdfViewProvider: React.FC<IProps> = props => {
  const { url, mode, scale, multiview, storageKeyScope, children } = props
  const storageKey = `${storageKeyScope}/filetype/pdf`
  const viewmodel: PdfViewViewModel | null = useViewModel<PdfViewViewModel>(() => {
    const rawViewData: Partial<IPdfViewData> = JSON.parse(
      window.localStorage.getItem(storageKey) || '{}',
    )
    const viewData: IPdfViewData = PdfViewViewModel.normalize(rawViewData)
    return new PdfViewViewModel({
      url,
      mode: mode ?? viewData.mode,
      scale: scale ?? viewData.scale,
      multiview: multiview ?? viewData.multiview,
    })
  })
  const context: IPdfViewContext | null = React.useMemo<IPdfViewContext | null>(
    () => (viewmodel ? { viewmodel } : null),
    [viewmodel],
  )

  if (!viewmodel || !context) return <React.Fragment />

  return (
    <React.Fragment>
      <PdfViewContextType.Provider value={context}>{children}</PdfViewContextType.Provider>
      <SideEffect
        viewmodel={viewmodel}
        url={url}
        mode={mode}
        scale={scale}
        multiview={multiview}
        storageKey={storageKey}
      />
    </React.Fragment>
  )
}

PdfViewProvider.displayName = 'PdfViewProvider'

// /////////////////////////////////////////////////////////////////////////////////////////////////

interface ISideEffectProps {
  readonly viewmodel: PdfViewViewModel
  readonly url: string | null
  readonly mode?: ModeEnum
  readonly scale?: number
  readonly multiview?: boolean
  readonly storageKey: string
}

const SideEffect: React.FC<ISideEffectProps> = props => {
  const { viewmodel, url, mode, scale, multiview, storageKey } = props

  usePersist(viewmodel, storageKey, [
    viewmodel.mode$,
    viewmodel.scale$,
    viewmodel.multiview$,
    viewmodel.pageNo$,
    viewmodel.pageTotal$,
  ])
  useSyncProps(viewmodel, mode, scale, multiview)
  useData(viewmodel, url)

  return <React.Fragment />
}

SideEffect.displayName = 'PdfViewSideEffect'

// /////////////////////////////////////////////////////////////////////////////////////////////////

const useSyncProps = (
  viewmodel: PdfViewViewModel,
  mode: ModeEnum | undefined,
  scale: number | undefined,
  multiview: boolean | undefined,
): void => {
  React.useEffect(() => {
    if (viewmodel.disposed) return
    viewmodel.mode$.next(mode ?? viewmodel.mode$.getSnapshot())
  }, [viewmodel, mode])

  React.useEffect(() => {
    if (viewmodel.disposed) return
    viewmodel.scale$.next(scale ?? viewmodel.scale$.getSnapshot())
  }, [viewmodel, scale])

  React.useEffect(() => {
    if (viewmodel.disposed) return
    viewmodel.multiview$.next(multiview ?? viewmodel.multiview$.getSnapshot())
  }, [viewmodel, multiview])
}

const useData = (viewmodel: PdfViewViewModel, url: string | null): void => {
  React.useEffect(() => {
    if (viewmodel.disposed) return
    viewmodel.url$.next(url)
  }, [viewmodel, url])
}
