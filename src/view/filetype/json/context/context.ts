import React from 'react'
import { JsonViewViewModel } from './viewmodel'

export interface IJsonViewContext {
  readonly viewmodel: JsonViewViewModel
}

export const JsonViewContextType = React.createContext<IJsonViewContext>({
  viewmodel: new JsonViewViewModel({
    workspace: null,
    filepath: '/dev/null',
  }),
})
JsonViewContextType.displayName = 'JsonViewContextType'

export const useJsonViewViewModel = (): JsonViewViewModel => {
  return React.useContext(JsonViewContextType).viewmodel
}
