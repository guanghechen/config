import React from 'react'
import { MarkdownViewViewModel } from './viewmodel'

export interface IMarkdownViewContext {
  readonly viewmodel: MarkdownViewViewModel
}

export const MarkdownViewContextType = React.createContext<IMarkdownViewContext>({
  viewmodel: new MarkdownViewViewModel(),
})

export const useMarkdownViewViewModel = (): MarkdownViewViewModel => {
  const context = React.useContext(MarkdownViewContextType)
  return context.viewmodel
}
