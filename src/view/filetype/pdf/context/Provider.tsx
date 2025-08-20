import { Computed } from '@guanghechen/react-viewmodel'
import React from 'react'
import { useSingleton } from '@/hook/useSingleton'
import type { IPdfViewContext } from './context'
import { PdfViewContextType } from './context'
import type { IPdfViewData, ModeEnum } from './types'
import { PdfViewViewModel } from './viewmodel'

const storageKey: string = '#/view/filetype/pdf'

interface IProps {
  readonly workspace: string | null
  readonly filepath: string
  readonly filepathDirtyTick: number
  readonly mode?: ModeEnum
  readonly scale?: number
  readonly multiview?: boolean
  readonly children: React.ReactNode
}

export const PdfViewProvider: React.FC<IProps> = props => {
  const { workspace, filepath, mode, scale, multiview, children } = props
  const viewmodel: PdfViewViewModel | null = useSingleton<PdfViewViewModel>(() => {
    const rawViewData: Partial<IPdfViewData> = JSON.parse(
      window.localStorage.getItem(storageKey) || '{}',
    )
    const viewData: IPdfViewData = PdfViewViewModel.normalize(rawViewData)
    return new PdfViewViewModel({
      workspace,
      filepath,
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
        workspace={workspace}
        filepath={filepath}
        mode={mode}
        scale={scale}
        multiview={multiview}
      />
    </React.Fragment>
  )
}

PdfViewProvider.displayName = 'PdfViewProvider'

// /////////////////////////////////////////////////////////////////////////////////////////////////

interface ISideEffectProps {
  readonly viewmodel: PdfViewViewModel
  readonly workspace: string | null
  readonly filepath: string
  readonly mode?: ModeEnum
  readonly scale?: number
  readonly multiview?: boolean
}

const SideEffect: React.FC<ISideEffectProps> = props => {
  const { viewmodel, workspace, filepath, mode, scale, multiview } = props

  usePersistent(viewmodel)
  useSyncProps(viewmodel, workspace, filepath, mode, scale, multiview)

  return <React.Fragment />
}

SideEffect.displayName = 'PdfViewSideEffect'

// /////////////////////////////////////////////////////////////////////////////////////////////////

const usePersistent = (viewmodel: PdfViewViewModel): void => {
  React.useEffect(() => {
    const computed = Computed.fromObservables(
      [viewmodel.mode$, viewmodel.scale$, viewmodel.multiview$],
      () => {
        const data: IPdfViewData = viewmodel.dump()
        window.localStorage.setItem(storageKey, JSON.stringify(data))
      },
    )
    return (): void => {
      computed.dispose()
    }
  }, [viewmodel])
}

const useSyncProps = (
  viewmodel: PdfViewViewModel,
  workspace: string | null,
  filepath: string,
  mode: ModeEnum | undefined,
  scale: number | undefined,
  multiview: boolean | undefined,
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
    viewmodel.scale$.next(scale ?? viewmodel.scale$.getSnapshot())
  }, [viewmodel, scale])

  React.useEffect(() => {
    if (viewmodel.disposed) return
    viewmodel.multiview$.next(multiview ?? viewmodel.multiview$.getSnapshot())
  }, [viewmodel, multiview])
}
