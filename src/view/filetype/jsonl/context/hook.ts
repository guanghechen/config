import React from 'react'
import { JsonlViewContextType } from './context'
import type { JsonlViewViewModel } from './viewmodel'

export const useJsonlViewViewModel = (): JsonlViewViewModel => {
  return React.useContext(JsonlViewContextType).viewmodel
}
