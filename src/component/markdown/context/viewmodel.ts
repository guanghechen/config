import equals from '@guanghechen/equal'
import { Computed, State, ViewModel } from '@guanghechen/react-viewmodel'
import type { Definition, FootnoteDefinition, Root } from '@yozora/ast'
import { calcDefinitionMap, calcFootnoteDefinitionMap } from '@yozora/ast-util'
import type { INodeRendererMap } from './types'

export interface IMarkdownViewModelProps {
  /**
   * Markdown texts.
   */
  readonly ast: Root
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

export class MarkdownViewModel extends ViewModel {
  public readonly ast$: State<Root>
  public readonly rendererMap$: State<Readonly<INodeRendererMap>>
  public readonly showCodeLineno$: State<boolean>
  public readonly themeScheme$: State<string>
  public readonly definitionMap$: Computed<Readonly<Record<string, Definition>>>
  public readonly footnoteDefinitionMap$: Computed<Readonly<Record<string, FootnoteDefinition>>>

  constructor(props: IMarkdownViewModelProps) {
    super()

    const {
      ast,
      presetDefinitionMap,
      presetFootnoteDefinitionMap,
      rendererMap,
      showCodeLineno,
      themeScheme,
    } = props

    const ast$: State<Root> = new State<Root>(ast, { equals })
    const definitionMap$ = Computed.fromObservables(
      [ast$],
      ([ast]): Readonly<Record<string, Definition>> => {
        const presetDefinitions: Definition[] = Object.values({ ...presetDefinitionMap })
        const { root, definitionMap } = calcDefinitionMap(ast, undefined, presetDefinitions)
        ast$.next(root)
        return definitionMap
      },
    )
    const footnoteDefinitionMap$ = Computed.fromObservables(
      [ast$],
      ([ast]): Readonly<Record<string, FootnoteDefinition>> => {
        const presetFootnoteDefinitions: FootnoteDefinition[] = Object.values({
          ...presetFootnoteDefinitionMap,
        })
        const { root, footnoteDefinitionMap } = calcFootnoteDefinitionMap(
          ast,
          undefined,
          presetFootnoteDefinitions,
          true,
        )
        ast$.next(root)
        return footnoteDefinitionMap
      },
    )

    this.ast$ = ast$
    this.definitionMap$ = definitionMap$
    this.footnoteDefinitionMap$ = footnoteDefinitionMap$
    this.rendererMap$ = new State(rendererMap)
    this.showCodeLineno$ = new State<boolean>(showCodeLineno)
    this.themeScheme$ = new State<string>(themeScheme)
  }

  public setContent = (ast: Root): void => {
    this.ast$.next(ast)
  }
}
