import React from 'react'
import { JsonViewContextType } from './context'
import type { JsonViewViewModel } from './viewmodel'

export const useJsonViewViewModel = (): JsonViewViewModel => {
  const context = React.useContext(JsonViewContextType)
  return context.viewmodel
}
