import React from 'react'
import { HtmlViewViewModel } from './viewmodel'

export interface IHtmlViewContext {
  readonly viewmodel: HtmlViewViewModel
}

export const HtmlViewContextType = React.createContext<IHtmlViewContext>({
  viewmodel: new HtmlViewViewModel(),
})

export const useHtmlViewViewModel = (): HtmlViewViewModel => {
  const context = React.useContext(HtmlViewContextType)
  return context.viewmodel
}
