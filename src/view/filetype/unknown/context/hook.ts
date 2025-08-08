import React from 'react'
import { UnknownViewContextType } from './context'
import type { UnknownViewViewModel } from './viewmodel'

export const useUnknownViewViewModel = (): UnknownViewViewModel => {
  const context = React.useContext(UnknownViewContextType)
  return context.viewmodel
}
