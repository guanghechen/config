import React from 'react'
import { PdfViewViewModel } from './viewmodel'

export interface IPdfViewContext {
  readonly viewmodel: PdfViewViewModel
}

export const PdfViewContextType = React.createContext<IPdfViewContext>({
  viewmodel: new PdfViewViewModel({
    workspace: null,
    filepath: '/dev/null',
  }),
})
