import equals from '@guanghechen/equal'
import { Computed, State, ViewModel } from '@guanghechen/react-viewmodel'
import type { Definition, Root } from '@yozora/ast'
import { calcDefinitionMap } from '@yozora/ast-util'
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

  constructor(props: IMarkdownViewModelProps) {
    super()

    const { ast, presetDefinitionMap, rendererMap, showCodeLineno, themeScheme } = props

    const ast$: State<Root> = new State<Root>(ast, { equals })
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

    this.ast$ = ast$
    this.definitionMap$ = definitionMap$
    this.rendererMap$ = new State(rendererMap)
    this.showCodeLineno$ = new State<boolean>(showCodeLineno)
    this.themeScheme$ = new State<string>(themeScheme)
  }

  public setContent = (ast: Root): void => {
    this.ast$.next(ast)
  }
}
