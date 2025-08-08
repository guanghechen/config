import React from 'react'
import { ExcalidrawViewViewModel } from './viewmodel'

export interface IExcalidrawViewContext {
  readonly viewmodel: ExcalidrawViewViewModel
}

export const ExcalidrawViewContextType = React.createContext<IExcalidrawViewContext>({
  viewmodel: new ExcalidrawViewViewModel(),
})
