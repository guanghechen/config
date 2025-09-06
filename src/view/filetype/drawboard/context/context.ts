import React from 'react'
import type { DrawboardViewViewModel } from './viewmodel'

export interface IDrawboardViewContext {
  readonly viewmodel: DrawboardViewViewModel
}

export const DrawboardViewContextType = React.createContext<IDrawboardViewContext>(
  null as unknown as IDrawboardViewContext,
)
DrawboardViewContextType.displayName = 'DrawboardViewContextType'

export const useDrawboardViewViewModel = (): DrawboardViewViewModel => {
  return React.useContext(DrawboardViewContextType).viewmodel
}
