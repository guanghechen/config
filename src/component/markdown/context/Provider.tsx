import { useDeepCompareMemo } from '@guanghechen/react-hooks'
import type { Definition, Root } from '@yozora/ast'
import React from 'react'
import { buildNodeRendererMap } from '../renderer'
import type { IMarkdownContext } from './context'
import { MarkdownContextType } from './context'
import type { INodeRendererMap } from './types'
import { MarkdownViewModel } from './viewmodel'

interface IProps {
  /**
   * The markdown file path.
   */
  readonly filepath: string
  /**
   * Text content of markdown.
   */
  readonly ast: Root
  /**
   * Customized node renderer mpa.
   */
  readonly customizedRendererMap?: Readonly<Partial<INodeRendererMap>>
  /**
   * Preset Link / Image reference definitions.
   */
  readonly presetDefinitionMap?: Readonly<Record<string, Definition>>
  /**
   * Whether if show lineno for code block.
   */
  readonly showCodeLineno?: boolean
  /**
   * Markdown theme scheme.
   */
  readonly theme: string
  /**
   * Children component.
   */
  readonly children?: React.ReactNode
}

export const MarkdownProvider: React.FC<IProps> = props => {
  const { customizedRendererMap, showCodeLineno = true, filepath, ast, theme } = props

  const presetDefinitionMap: Record<string, Readonly<Definition>> = useDeepCompareMemo(
    () => props.presetDefinitionMap ?? {},
    [props.presetDefinitionMap],
  )
  const [viewmodel] = React.useState<MarkdownViewModel>(() => {
    return new MarkdownViewModel({
      filepath,
      ast,
      rendererMap: buildNodeRendererMap(customizedRendererMap),
      presetDefinitionMap,
      showCodeLineno,
      themeScheme: theme,
    })
  })

  const context = React.useMemo<IMarkdownContext>(() => ({ viewmodel }), [viewmodel])

  return (
    <React.Fragment>
      <SideEffect
        viewmodel={viewmodel}
        filepath={filepath}
        ast={ast}
        showCodeLineno={showCodeLineno}
        theme={theme}
      />
      <MarkdownContextType.Provider value={context}>{props.children}</MarkdownContextType.Provider>
    </React.Fragment>
  )
}
MarkdownProvider.displayName = 'MarkdownProvider'

interface ISideEffectProps {
  readonly viewmodel: MarkdownViewModel
  readonly filepath: string
  readonly ast: Root
  readonly showCodeLineno: boolean
  readonly theme: string
}

const SideEffect: React.FC<ISideEffectProps> = props => {
  const { viewmodel, filepath, ast, showCodeLineno, theme } = props

  React.useEffect(() => {
    viewmodel.setContent(filepath, ast)
  }, [viewmodel, filepath, ast])

  React.useEffect(() => {
    viewmodel.showCodeLineno$.next(showCodeLineno)
  }, [viewmodel, showCodeLineno])

  React.useEffect(() => {
    viewmodel.themeScheme$.next(theme)
  }, [viewmodel, theme])

  return <React.Fragment />
}
