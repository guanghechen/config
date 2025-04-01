import React from 'react'
import type { MarkdownViewModel } from './viewmodel'

export interface IMarkdownContext {
  readonly viewmodel: MarkdownViewModel
}

export const MarkdownContextType = React.createContext<IMarkdownContext>(
  null as unknown as IMarkdownContext,
)
MarkdownContextType.displayName = 'MarkdownContextType'
