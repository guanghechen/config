import React from 'react'
import type { IWhiteboardViewContext } from './context'
import { WhiteboardViewContextType } from './context'
import type { IWhiteboardRichContent } from './types'
import { WhiteboardViewViewModel } from './viewmodel'

interface IProps {
  readonly content?: string | null
  readonly richContent?: IWhiteboardRichContent | null
  readonly filetype?: string
  readonly children: React.ReactNode
}

export const WhiteboardViewProvider: React.FC<IProps> = ({
  content,
  richContent,
  filetype,
  children,
}) => {
  const viewmodel = React.useMemo(
    () => new WhiteboardViewViewModel({ content, richContent, filetype }),
    [content, richContent, filetype],
  )

  const contextValue = React.useMemo<IWhiteboardViewContext>(() => ({ viewmodel }), [viewmodel])

  return (
    <WhiteboardViewContextType.Provider value={contextValue}>
      {children}
    </WhiteboardViewContextType.Provider>
  )
}
