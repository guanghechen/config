import React from 'react'
import { SvgViewViewModel } from './viewmodel'

export interface ISvgViewContext {
  readonly viewmodel: SvgViewViewModel
}

export const SvgViewContextType = React.createContext<ISvgViewContext>({
  viewmodel: new SvgViewViewModel({
    workspace: null,
    filepath: '/dev/null',
  }),
})
