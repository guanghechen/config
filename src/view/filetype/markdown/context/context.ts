import React from 'react'
import type { MarkdownViewViewModel } from './viewmodel'

export interface IMarkdownViewContext {
  readonly viewmodel: MarkdownViewViewModel
}

export const MarkdownViewContextType = React.createContext<IMarkdownViewContext>({
  viewmodel: null as unknown as MarkdownViewViewModel,
})

export const useMarkdownViewViewModel = (): MarkdownViewViewModel => {
  const context = React.useContext(MarkdownViewContextType)
  return context.viewmodel
}
