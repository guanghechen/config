import React from 'react'
import type { MarkdownViewModel } from './viewmodel'

export interface INodeRendererContext {
  readonly viewmodel: MarkdownViewModel
}

export const NodeRendererContextType = React.createContext<INodeRendererContext>(
  null as unknown as INodeRendererContext,
)
NodeRendererContextType.displayName = 'NodeRendererContextType'

export const useNodeRendererContext = (): INodeRendererContext =>
  React.useContext(NodeRendererContextType)

export const useMarkdownViewmodel = (): MarkdownViewModel =>
  React.useContext(NodeRendererContextType).viewmodel
