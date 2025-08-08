import React from 'react'
import { UnknownViewViewModel } from './viewmodel'

export interface IUnknownViewContext {
  readonly viewmodel: UnknownViewViewModel
}

export const UnknownViewContextType = React.createContext<IUnknownViewContext>({
  viewmodel: new UnknownViewViewModel(),
})
