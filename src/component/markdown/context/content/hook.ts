import { useComputed } from '@guanghechen/react-viewmodel'
import type { Definition, FootnoteDefinition, Root } from '@yozora/ast'
import React from 'react'
import { MarkdownContentContextType } from './context'
import type { MarkdownContentViewModel } from './viewmodel'

export const useMarkdownContentViewmodel = (): MarkdownContentViewModel =>
  React.useContext(MarkdownContentContextType).viewmodel

export const useMarkdownAst = (): Root => {
  const viewmodel = useMarkdownContentViewmodel()
  const ast: Root = useComputed(viewmodel.ast$)
  return ast
}

export const useMarkdownDefinitionMap = (): Readonly<Record<string, Definition>> => {
  const viewmodel = useMarkdownContentViewmodel()
  const definitionMap: Readonly<Record<string, Definition>> = useComputed(viewmodel.definitionMap$)
  return definitionMap
}

export const useMarkdownFootnoteDefinitionMap = (): Readonly<
  Record<string, FootnoteDefinition>
> => {
  const viewmodel = useMarkdownContentViewmodel()
  const footnoteDefinitionMap: Readonly<Record<string, FootnoteDefinition>> = useComputed(
    viewmodel.footnoteDefinitionMap$,
  )
  return footnoteDefinitionMap
}
