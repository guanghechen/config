import React from 'react'
import { TextViewViewModel } from './viewmodel'

export interface ITextViewContext {
  readonly viewmodel: TextViewViewModel
}

export const TextViewContextType = React.createContext<ITextViewContext>({
  viewmodel: new TextViewViewModel(),
})

export const useTextViewViewModel = (): TextViewViewModel => {
  const context = React.useContext(TextViewContextType)
  return context.viewmodel
}