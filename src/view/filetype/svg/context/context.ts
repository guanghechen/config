import React from 'react'
import type { SvgViewViewModel } from './viewmodel'

export interface ISvgViewContext {
  readonly viewmodel: SvgViewViewModel
}

export const SvgViewContextType = React.createContext<ISvgViewContext>({
  viewmodel: null as unknown as SvgViewViewModel,
})

export const useSvgViewViewModel = (): SvgViewViewModel => {
  const context = React.useContext(SvgViewContextType)
  return context.viewmodel
}
