import { Computed, State, ViewModel } from '@guanghechen/react-viewmodel'
import { type Definition, type Root } from '@yozora/ast'
import { calcDefinitionMap } from '@yozora/ast-util'
import { parseMarkdown } from '../parser'
import type { INodeRendererMap } from './types'

export interface IMarkdownViewModelProps {
  /**
   * Markdown filepath.
   */
  readonly filepath: string
  /**
   * Markdown texts.
   */
  readonly content: string
  /**
   * Preset Link / Image reference definitions.
   */
  readonly presetDefinitionMap: Readonly<Record<string, Definition>>
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
  public readonly filepath$: State<string>
  public readonly content$: State<string>
  public readonly rendererMap$: State<Readonly<INodeRendererMap>>
  public readonly showCodeLineno$: State<boolean>
  public readonly themeScheme$: State<string>
  public readonly ast$: Computed<Root>
  public readonly definitionMap$: Computed<Readonly<Record<string, Definition>>>

  constructor(props: IMarkdownViewModelProps) {
    super()

    const { filepath, content, presetDefinitionMap, rendererMap, showCodeLineno, themeScheme } =
      props

    const filepath$: State<string> = new State<string>(filepath)
    const content$: State<string> = new State<string>(content)
    const ast$: Computed<Root> = Computed.fromObservables(
      [content$],
      ([text]): Root =>
        parseMarkdown(text, {
          shouldReservePosition: true,
        }),
    )
    const definitionMap$ = Computed.fromObservables(
      [ast$],
      ([ast]): Readonly<Record<string, Definition>> => {
        const definitionMap: Record<string, Definition> = {
          ...presetDefinitionMap,
        }
        const map: Readonly<Record<string, Definition>> = calcDefinitionMap(ast).definitionMap
        for (const [key, val] of Object.entries(map)) definitionMap[key] = val
        return definitionMap
      },
    )

    this.filepath$ = filepath$
    this.content$ = content$
    this.ast$ = ast$
    this.definitionMap$ = definitionMap$
    this.rendererMap$ = new State(rendererMap)
    this.showCodeLineno$ = new State<boolean>(showCodeLineno)
    this.themeScheme$ = new State<string>(themeScheme)
  }

  public setContent = (filepath: string, content: string): void => {
    this.filepath$.next(filepath)
    this.content$.next(content)
  }
}
