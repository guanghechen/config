import React from 'react'
import type { HtmlViewViewModel } from './viewmodel'

export interface IHtmlViewContext {
  readonly viewmodel: HtmlViewViewModel
}

export const HtmlViewContextType = React.createContext<IHtmlViewContext>({
  viewmodel: null as unknown as HtmlViewViewModel,
})

export const useHtmlViewViewModel = (): HtmlViewViewModel => {
  const context = React.useContext(HtmlViewContextType)
  return context.viewmodel
}
