import React from 'react'
import type { MarkdownContentViewModel } from './viewmodel'

export interface IMarkdownContentContext {
  readonly viewmodel: MarkdownContentViewModel
}

export const MarkdownContentContextType = React.createContext<IMarkdownContentContext>(
  null as unknown as IMarkdownContentContext,
)
MarkdownContentContextType.displayName = 'MarkdownContentContextType'
