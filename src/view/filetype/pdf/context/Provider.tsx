import React from 'react'
import type { IPdfViewContext } from './context'
import { PdfViewContextType } from './context'
import { PdfViewViewModel } from './viewmodel'

interface IProps {
  readonly workspace: string | null
  readonly filepath: string
  readonly children: React.ReactNode
}

export const PdfViewProvider: React.FC<IProps> = props => {
  const { workspace, filepath, children } = props
  const [viewmodel] = React.useState(
    () =>
      new PdfViewViewModel({
        workspace,
        filepath,
      }),
  )

  const context: IPdfViewContext = React.useMemo<IPdfViewContext>(
    () => ({ viewmodel }),
    [viewmodel],
  )

  return <PdfViewContextType.Provider value={context}>{children}</PdfViewContextType.Provider>
}

PdfViewProvider.displayName = 'PdfViewProvider'
