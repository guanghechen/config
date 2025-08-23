import React from 'react'
import type { ExcalidrawViewViewModel } from './viewmodel'

export interface IExcalidrawViewContext {
  readonly viewmodel: ExcalidrawViewViewModel
}

export const ExcalidrawViewContextType = React.createContext<IExcalidrawViewContext>({
  viewmodel: null as unknown as ExcalidrawViewViewModel,
})

export const useExcalidrawViewViewModel = (): ExcalidrawViewViewModel => {
  const context = React.useContext(ExcalidrawViewContextType)
  return context.viewmodel
}
