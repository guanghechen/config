import React from 'react'
import { Composer } from './Composer'
import { PdfViewProvider } from './context/Provider'

interface IProps {
  readonly workspace: string | null
  readonly filepath: string
  readonly mainScrollableContainer: HTMLDivElement | null
}

export const PDFView: React.FC<IProps> = props => {
  const { filepath, workspace, mainScrollableContainer } = props

  return (
    <PdfViewProvider workspace={workspace} filepath={filepath}>
      <Composer mainScrollableContainer={mainScrollableContainer} />
    </PdfViewProvider>
  )
}

PDFView.displayName = 'PDFView'
