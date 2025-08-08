import React from 'react'
import { JsonlViewViewModel } from './viewmodel'

export interface IJsonlViewContext {
  readonly viewmodel: JsonlViewViewModel
}

export const JsonlViewContextType = React.createContext<IJsonlViewContext>({
  viewmodel: new JsonlViewViewModel({
    workspace: null,
    filepath: '/dev/null',
  }),
})
