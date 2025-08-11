import React from 'react'
import type { IPdfViewContext } from './context'
import { PdfViewContextType } from './context'
import { PdfViewViewModel } from './viewmodel'

interface IProps {
  readonly workspace: string | null
  readonly filepath: string
  readonly pages?: number
  readonly pageno?: number
  readonly scale?: number
  readonly multiview?: boolean
  readonly children: React.ReactNode
}

export const PdfViewProvider: React.FC<IProps> = props => {
  const { workspace, filepath, pages, pageno, scale, multiview, children } = props
  const [viewmodel] = React.useState<PdfViewViewModel>(
    () => new PdfViewViewModel({ workspace, filepath, pages, pageno, scale, multiview }),
  )

  const context: IPdfViewContext = React.useMemo<IPdfViewContext>(
    () => ({ viewmodel }),
    [viewmodel],
  )

  return (
    <PdfViewContextType.Provider value={context}>
      {children}
      <SideEffect
        viewmodel={viewmodel}
        workspace={workspace}
        filepath={filepath}
        pages={pages}
        pageno={pageno}
        scale={scale}
        multiview={multiview}
      />
    </PdfViewContextType.Provider>
  )
}

PdfViewProvider.displayName = 'PdfViewProvider'

// /////////////////////////////////////////////////////////////////////////////////////////////////

interface ISideEffectProps {
  readonly viewmodel: PdfViewViewModel
  readonly workspace: string | null
  readonly filepath: string
  readonly pages?: number
  readonly pageno?: number
  readonly scale?: number
  readonly multiview?: boolean
}

const SideEffect: React.FC<ISideEffectProps> = props => {
  const { viewmodel, workspace, filepath, pages, pageno, scale, multiview } = props

  React.useEffect(() => {
    viewmodel.workspace$.next(workspace)
  }, [viewmodel.workspace$, workspace])

  React.useEffect(() => {
    viewmodel.filepath$.next(filepath)
  }, [viewmodel.filepath$, filepath])

  React.useEffect(() => {
    viewmodel.pages$.next(pages ?? 1)
  }, [viewmodel.pages$, pages])

  React.useEffect(() => {
    viewmodel.pageno$.next(pageno ?? 1)
  }, [viewmodel.pageno$, pageno])

  React.useEffect(() => {
    viewmodel.scale$.next(scale ?? 1)
  }, [viewmodel.scale$, scale])

  React.useEffect(() => {
    viewmodel.multiview$.next(multiview ?? false)
  }, [viewmodel.multiview$, multiview])

  return <React.Fragment />
}

SideEffect.displayName = 'PdfViewSideEffect'
