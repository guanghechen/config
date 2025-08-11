import React from 'react'
import { MarkdownViewContextType } from './context'
import { type IMarkdownViewViewModelProps, MarkdownViewViewModel } from './viewmodel'

interface IProps extends IMarkdownViewViewModelProps {
  readonly children: React.ReactNode
}

export const MarkdownViewProvider: React.FC<IProps> = ({ children, ...viewModelProps }) => {
  const viewmodel = React.useMemo(() => new MarkdownViewViewModel(viewModelProps), [viewModelProps])

  const value = React.useMemo(
    () => ({
      viewmodel,
    }),
    [viewmodel],
  )

  return (
    <MarkdownViewContextType.Provider value={value}>{children}</MarkdownViewContextType.Provider>
  )
}

MarkdownViewProvider.displayName = 'MarkdownViewProvider'
