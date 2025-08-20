import React from 'react'
import { ExcalidrawViewViewModel } from './viewmodel'

export interface IExcalidrawViewContext {
  readonly viewmodel: ExcalidrawViewViewModel
}

export const ExcalidrawViewContextType = React.createContext<IExcalidrawViewContext>({
  viewmodel: new ExcalidrawViewViewModel({
    workspace: null,
    filepath: '/dev/null',
  }),
})

export const useExcalidrawViewViewModel = (): ExcalidrawViewViewModel => {
  const context = React.useContext(ExcalidrawViewContextType)
  return context.viewmodel
}
