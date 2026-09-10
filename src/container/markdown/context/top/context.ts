import React from 'react'
import type { MarkdownTopViewModel } from './viewmodel'

export interface IMarkdownTopContext {
  readonly viewmodel: MarkdownTopViewModel
  readonly onLinkClick?: React.MouseEventHandler<HTMLAnchorElement>
  readonly resolveLinkUrl: (url: string) => string
}

export const MarkdownTopContextType = React.createContext<IMarkdownTopContext>(
  null as unknown as IMarkdownTopContext,
)
MarkdownTopContextType.displayName = 'MarkdownTopContextType'

export const useMarkdownTopViewmodel = (): MarkdownTopViewModel =>
  React.useContext(MarkdownTopContextType).viewmodel

export const useMarkdownResolveLinkUrl = (): ((url: string) => string) =>
  React.useContext(MarkdownTopContextType).resolveLinkUrl

export const useMarkdownLinkClick = (): React.MouseEventHandler<HTMLAnchorElement> | undefined =>
  React.useContext(MarkdownTopContextType).onLinkClick
