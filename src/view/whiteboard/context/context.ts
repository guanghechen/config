import React from 'react'
import type { WhiteboardViewViewModel } from './viewmodel'

export interface IWhiteboardViewContext {
  readonly viewmodel: WhiteboardViewViewModel
}

export const WhiteboardViewContextType = React.createContext<IWhiteboardViewContext>(
  null as unknown as IWhiteboardViewContext,
)
WhiteboardViewContextType.displayName = 'WhiteboardViewContextType'

export const useWhiteboardViewmodel = (): WhiteboardViewViewModel => {
  return React.useContext(WhiteboardViewContextType).viewmodel
}
