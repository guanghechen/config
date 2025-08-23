import React from 'react'
import type { JsonViewViewModel } from './viewmodel'

export interface IJsonViewContext {
  readonly viewmodel: JsonViewViewModel
}

export const JsonViewContextType = React.createContext<IJsonViewContext>({
  viewmodel: null as unknown as JsonViewViewModel,
})
JsonViewContextType.displayName = 'JsonViewContextType'

export const useJsonViewViewModel = (): JsonViewViewModel => {
  return React.useContext(JsonViewContextType).viewmodel
}
