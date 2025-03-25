import { useComputed, useStateValue } from '@guanghechen/react-viewmodel'
import type { Definition, FootnoteDefinition, Root } from '@yozora/ast'
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

export const useMarkdownFootnoteDefinitionMap = (): Readonly<
  Record<string, FootnoteDefinition>
> => {
  const viewmodel = useMarkdownViewmodel()
  const footnoteDefinitionMap: Readonly<Record<string, FootnoteDefinition>> = useComputed(
    viewmodel.footnoteDefinitionMap$,
  )
  return footnoteDefinitionMap
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

export const useFootnoteHighlighting = (
  targetRef: React.RefObject<HTMLElement | null>,
  targetId: string,
): boolean => {
  const [highlighting, setHighlighting] = React.useState<boolean>(false)

  React.useEffect(() => {
    let timer: ReturnType<typeof setTimeout> | null = null

    const onHashChange = (): void => {
      const hash = window.location.hash

      if (hash === '#' + targetId) {
        setHighlighting(true)
        timer = setTimeout(() => {
          timer = null
          setHighlighting(false)
        }, 3000)

        targetRef.current?.scrollIntoView({ behavior: 'smooth', block: 'center' })
      }
    }

    onHashChange()

    window.addEventListener('hashchange', onHashChange)
    return () => {
      if (timer !== null) clearTimeout(timer)
      window.removeEventListener('hashchange', onHashChange)
    }
  }, [targetRef, targetId])

  return highlighting
}
