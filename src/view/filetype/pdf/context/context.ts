import React from 'react'
import type { PdfViewViewModel } from './viewmodel'

export interface IPdfViewContext {
  readonly viewmodel: PdfViewViewModel
}

export const PdfViewContextType = React.createContext<IPdfViewContext>({
  viewmodel: null as unknown as PdfViewViewModel,
})

export const usePdfViewViewModel = (): PdfViewViewModel => {
  const context = React.useContext(PdfViewContextType)
  return context.viewmodel
}
