import React from 'react'
import type { DrawboardViewModel } from './viewmodel'

export interface IDrawboardContext {
  readonly viewmodel: DrawboardViewModel
}

export const DrawboardContextType = React.createContext<IDrawboardContext>(
  null as unknown as IDrawboardContext,
)
DrawboardContextType.displayName = 'DrawboardContextType'
