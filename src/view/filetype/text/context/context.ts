import React from 'react'
import type { TextViewViewModel } from './viewmodel'

export interface ITextViewContext {
  readonly viewmodel: TextViewViewModel
}

export const TextViewContextType = React.createContext<ITextViewContext>({
  viewmodel: null as unknown as TextViewViewModel,
})

export const useTextViewViewModel = (): TextViewViewModel => {
  const context = React.useContext(TextViewContextType)
  return context.viewmodel
}
