import React from 'react'
import { SvgViewContextType } from './context'
import type { SvgViewViewModel } from './viewmodel'

export const useSvgViewViewModel = (): SvgViewViewModel => {
  const context = React.useContext(SvgViewContextType)
  return context.viewmodel
}
