import { State, ViewModel } from '@guanghechen/react-viewmodel'
import type { Definition, FootnoteDefinition, Root } from '@yozora/ast'
import { parseMarkdown } from '../../parser'
import type { INodeRendererMap } from '../../types'

interface IProps {
  /**
   * Preset Link / Image reference definitions.
   */
  readonly presetDefinitionMap: Readonly<Record<string, Definition>>
  /**
   * Preset footnote reference definitions.
   */
  readonly presetFootnoteDefinitionMap: Readonly<Record<string, FootnoteDefinition>>
  /**
   * Ast node renderer map.
   */
  readonly rendererMap: Readonly<INodeRendererMap>
  /**
   * Whether if show code lineno.
   */
  readonly showCodeLineno: boolean
  /**
   * React markdown theme scheme.
   */
  readonly themeScheme: string
}

export class MarkdownTopViewModel extends ViewModel {
  public readonly rendererMap$: State<Readonly<INodeRendererMap>>
  public readonly showCodeLineno$: State<boolean>
  public readonly themeScheme$: State<string>

  public readonly presetDefinitionMap: Readonly<Record<string, Definition>>
  public readonly presetFootnoteDefinitionMap: Readonly<Record<string, FootnoteDefinition>>

  constructor(props: IProps) {
    super()

    const {
      presetDefinitionMap,
      presetFootnoteDefinitionMap,
      rendererMap,
      showCodeLineno,
      themeScheme,
    } = props

    this.rendererMap$ = new State(rendererMap)
    this.showCodeLineno$ = new State<boolean>(showCodeLineno)
    this.themeScheme$ = new State<string>(themeScheme)

    this.presetDefinitionMap = presetDefinitionMap
    this.presetFootnoteDefinitionMap = presetFootnoteDefinitionMap
  }

  public parseMarkdown = (content: string): Root => {
    const ast: Root = parseMarkdown(content, {
      shouldReservePosition: false,
      presetDefinitions: Object.values(this.presetDefinitionMap),
      presetFootnoteDefinitions: Object.values(this.presetFootnoteDefinitionMap),
    })
    return ast
  }
}
