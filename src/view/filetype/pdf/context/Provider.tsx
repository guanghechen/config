import { Computed } from '@guanghechen/react-viewmodel'
import React from 'react'
import { ViewModelCleanupSideEffect } from '@/container/ViewModelCleanup'
import { useFileResult } from '@/hook/useFileResult'
import type { IPdfFileData } from '@/util/fetch'
import type { IPdfViewContext } from './context'
import { PdfViewContextType } from './context'
import type { IPdfViewData } from './types'
import { PdfViewViewModel } from './viewmodel'

const storageKey: string = '#/view/filetype/pdf'

interface IProps {
  readonly workspace: string | null
  readonly filepath: string
  readonly filepathDirtyTick: number
  readonly pages?: number
  readonly pageno?: number
  readonly scale?: number
  readonly multiview?: boolean
  readonly children: React.ReactNode
}

export const PdfViewProvider: React.FC<IProps> = props => {
  const { workspace, filepath, filepathDirtyTick, pages, pageno, scale, multiview, children } =
    props
  const [viewmodel] = React.useState<PdfViewViewModel>(() => {
    const initialData: Partial<IPdfViewData> = JSON.parse(
      window.localStorage.getItem(storageKey) || '{}',
    )
    return PdfViewViewModel.fromData({
      scale: scale ?? initialData.scale,
      multiview: multiview ?? initialData.multiview,
    })
  })

  const context: IPdfViewContext = React.useMemo<IPdfViewContext>(
    () => ({ viewmodel }),
    [viewmodel],
  )

  return (
    <React.Fragment>
      <PdfViewContextType.Provider value={context}>{children}</PdfViewContextType.Provider>
      <SideEffect
        viewmodel={viewmodel}
        workspace={workspace}
        filepath={filepath}
        filepathDirtyTick={filepathDirtyTick}
        pages={pages}
        pageno={pageno}
        scale={scale}
        multiview={multiview}
      />
      <ViewModelCleanupSideEffect viewmodel={viewmodel} />
    </React.Fragment>
  )
}

PdfViewProvider.displayName = 'PdfViewProvider'

// /////////////////////////////////////////////////////////////////////////////////////////////////

interface ISideEffectProps {
  readonly viewmodel: PdfViewViewModel
  readonly workspace: string | null
  readonly filepath: string
  readonly filepathDirtyTick: number
  readonly pages?: number
  readonly pageno?: number
  readonly scale?: number
  readonly multiview?: boolean
}

const SideEffect: React.FC<ISideEffectProps> = props => {
  const { viewmodel, workspace, filepath, filepathDirtyTick, pages, pageno, scale, multiview } =
    props

  const { data, error } = useFileResult<IPdfFileData>(workspace, filepath, filepathDirtyTick)

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
    const computed = Computed.fromObservables([viewmodel.scale$, viewmodel.multiview$], () => {
      const data: IPdfViewData = viewmodel.dump()
      window.localStorage.setItem(storageKey, JSON.stringify(data))
    })
    return (): void => {
      computed.dispose()
    }
  }, [viewmodel])

  React.useEffect(() => {
    if (viewmodel.disposed) return
    viewmodel.workspace$.next(workspace)
  }, [viewmodel.workspace$, workspace])

  React.useEffect(() => {
    if (viewmodel.disposed) return
    viewmodel.filepath$.next(filepath)
  }, [viewmodel.filepath$, filepath])

  React.useEffect(() => {
    if (viewmodel.disposed) return
    viewmodel.pages$.next(pages ?? 1)
  }, [viewmodel.pages$, pages])

  React.useEffect(() => {
    if (viewmodel.disposed) return
    viewmodel.pageno$.next(pageno ?? 1)
  }, [viewmodel.pageno$, pageno])

  React.useEffect(() => {
    if (viewmodel.disposed) return
    viewmodel.scale$.next(scale ?? viewmodel.scale$.getSnapshot())
  }, [viewmodel.scale$, scale])

  React.useEffect(() => {
    if (viewmodel.disposed) return
    viewmodel.multiview$.next(multiview ?? viewmodel.multiview$.getSnapshot())
  }, [viewmodel.multiview$, multiview])

  return <React.Fragment />
}

SideEffect.displayName = 'PdfViewSideEffect'
