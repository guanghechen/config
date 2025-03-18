import { useComputed, useStateValue } from '@guanghechen/react-viewmodel'
import type { Definition, Root } from '@yozora/ast'
import React from 'react'
import { MarkdownContextType } from './context'
import type { INodeRendererMap } from './types'
import type { MarkdownViewModel } from './viewmodel'

export const useMarkdownViewmodel = (): MarkdownViewModel =>
  React.useContext(MarkdownContextType).viewmodel

export const useMarkdownAst = (): Root => {
  const viewmodel = useMarkdownViewmodel()
  const ast: Root = useComputed(viewmodel.ast$)
  return ast
}

export const useMarkdownDarken = (): boolean => {
  const viewmodel = useMarkdownViewmodel()
  const theme = useStateValue(viewmodel.themeScheme$)
  return theme === 'darken'
}

export const useMarkdownDefinitionMap = (): Readonly<Record<string, Definition>> => {
  const viewmodel = useMarkdownViewmodel()
  const definitionMap: Readonly<Record<string, Definition>> = useComputed(viewmodel.definitionMap$)
  return definitionMap
}

export const useMarkdownRendererMap = (): Readonly<INodeRendererMap> => {
  const viewmodel = useMarkdownViewmodel()
  const rendererMap: Readonly<INodeRendererMap> = useStateValue(viewmodel.rendererMap$)
  return rendererMap
}

export const useMarkdownShowCodeLineNumber = (): boolean => {
  const viewmodel = useMarkdownViewmodel()
  const showCodeLineno: boolean = useStateValue(viewmodel.showCodeLineno$)
  return showCodeLineno
}
