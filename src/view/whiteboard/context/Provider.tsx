import React from 'react'
import type { IWhiteboardViewContext } from './context'
import { WhiteboardViewContextType } from './context'
import { WhiteboardViewViewModel } from './viewmodel'

interface IProps {
  readonly content?: string | null
  readonly filetype?: string
  readonly children: React.ReactNode
}

export const WhiteboardViewProvider: React.FC<IProps> = ({ content, filetype, children }) => {
  const viewmodel = React.useMemo(
    () => new WhiteboardViewViewModel({ content, filetype }),
    [content, filetype],
  )

  const contextValue = React.useMemo<IWhiteboardViewContext>(() => ({ viewmodel }), [viewmodel])

  return (
    <WhiteboardViewContextType.Provider value={contextValue}>
      {children}
    </WhiteboardViewContextType.Provider>
  )
}
