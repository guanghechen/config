import React from 'react'
import type { UnknownViewViewModel } from './viewmodel'

export interface IUnknownViewContext {
  readonly viewmodel: UnknownViewViewModel
}

export const UnknownViewContextType = React.createContext<IUnknownViewContext>({
  viewmodel: null as unknown as UnknownViewViewModel,
})

export const useUnknownViewViewModel = (): UnknownViewViewModel => {
  const context = React.useContext(UnknownViewContextType)
  return context.viewmodel
}
