import React from 'react'
import { DrawboardContextType } from './context'
import type { DrawboardViewModel } from './viewmodel'

export const useDrawboardContext = (): { viewmodel: DrawboardViewModel } => {
  return React.useContext(DrawboardContextType)
}
