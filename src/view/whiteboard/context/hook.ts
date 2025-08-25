import React from 'react'
import { WhiteboardViewContextType } from './context'
import type { WhiteboardViewViewModel } from './viewmodel'

export const useWhiteboardViewmodel = (): WhiteboardViewViewModel => {
  return React.useContext(WhiteboardViewContextType).viewmodel
}
