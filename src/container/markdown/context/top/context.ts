import React from 'react'
import type { MarkdownTopViewModel } from './viewmodel'

export interface IMarkdownTopContext {
  readonly viewmodel: MarkdownTopViewModel
}

export const MarkdownTopContextType = React.createContext<IMarkdownTopContext>(
  null as unknown as IMarkdownTopContext,
)
MarkdownTopContextType.displayName = 'MarkdownTopContextType'

export const useMarkdownTopViewmodel = (): MarkdownTopViewModel =>
  React.useContext(MarkdownTopContextType).viewmodel
