import { useDeepCompareMemo } from '@guanghechen/react-hooks'
import { useViewModel } from '@guanghechen/react-viewmodel'
import type { Definition, FootnoteDefinition } from '@yozora/ast'
import React from 'react'
import { buildNodeRendererMap } from '../../renderer'
import type { INodeRendererMap } from '../../types'
import type { IMarkdownTopContext } from './context'
import { MarkdownTopContextType } from './context'
import { MarkdownTopViewModel } from './viewmodel'

interface IProps {
  /**
   * Customized node renderer mpa.
   */
  readonly customizedRendererMap?: Readonly<Partial<INodeRendererMap>>
  /**
   * Preset Link / Image reference definitions.
   */
  readonly presetDefinitionMap?: Readonly<Record<string, Definition>>
  /**
   * Preset footnote reference definitions.
   */
  readonly presetFootnoteDefinitionMap?: Readonly<Record<string, FootnoteDefinition>>
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

export const MarkdownTopProvider: React.FC<IProps> = props => {
  const { customizedRendererMap, showCodeLineno = true, theme } = props

  const presetDefinitionMap: Record<string, Readonly<Definition>> = useDeepCompareMemo(
    () => props.presetDefinitionMap ?? {},
    [props.presetDefinitionMap],
  )
  const presetFootnoteDefinitionMap: Record<
    string,
    Readonly<FootnoteDefinition>
  > = useDeepCompareMemo(
    () => props.presetFootnoteDefinitionMap ?? {},
    [props.presetFootnoteDefinitionMap],
  )
  const viewmodel: MarkdownTopViewModel | null = useViewModel<MarkdownTopViewModel>(() => {
    return new MarkdownTopViewModel({
      rendererMap: buildNodeRendererMap(customizedRendererMap),
      presetDefinitionMap,
      presetFootnoteDefinitionMap,
      showCodeLineno,
      themeScheme: theme,
    })
  })

  const context: IMarkdownTopContext | null = React.useMemo<IMarkdownTopContext | null>(
    () => (viewmodel ? { viewmodel } : null),
    [viewmodel],
  )

  if (!viewmodel || !context) return <React.Fragment />

  return (
    <React.Fragment>
      <MarkdownTopContextType.Provider value={context}>
        {props.children}
      </MarkdownTopContextType.Provider>
      <SideEffect viewmodel={viewmodel} showCodeLineno={showCodeLineno} theme={theme} />
    </React.Fragment>
  )
}
MarkdownTopProvider.displayName = 'MarkdownTopProvider'

interface ISideEffectProps {
  readonly viewmodel: MarkdownTopViewModel
  readonly showCodeLineno: boolean
  readonly theme: string
}

const SideEffect: React.FC<ISideEffectProps> = props => {
  const { viewmodel, showCodeLineno, theme } = props

  React.useEffect(() => {
    viewmodel.showCodeLineno$.next(showCodeLineno)
  }, [viewmodel, showCodeLineno])

  React.useEffect(() => {
    viewmodel.themeScheme$.next(theme)
  }, [viewmodel, theme])

  return <React.Fragment />
}
