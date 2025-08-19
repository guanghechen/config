import React from 'react'
import { PdfViewViewModel } from './viewmodel'

export interface IPdfViewContext {
  readonly viewmodel: PdfViewViewModel
}

export const PdfViewContextType = React.createContext<IPdfViewContext>({
  viewmodel: new PdfViewViewModel({
    filepath: '/dev/null',
  }),
})

export const usePdfViewViewModel = (): PdfViewViewModel => {
  const context = React.useContext(PdfViewContextType)
  return context.viewmodel
}
