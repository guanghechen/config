import React from 'react'
import { JsonViewViewModel } from './viewmodel'

export interface IJsonViewContext {
  readonly viewmodel: JsonViewViewModel
}

export const JsonViewContextType = React.createContext<IJsonViewContext>({
  viewmodel: new JsonViewViewModel(),
})

export const useJsonViewViewModel = (): JsonViewViewModel => {
  const context = React.useContext(JsonViewContextType)
  return context.viewmodel
}
