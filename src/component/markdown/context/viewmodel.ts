import equals from '@guanghechen/equal'
import { Computed, State, ViewModel } from '@guanghechen/react-viewmodel'
import type { Definition, FootnoteDefinition, Image, ImageReference, Root } from '@yozora/ast'
import { ImageReferenceType, ImageType } from '@yozora/ast'
import type { IHeadingToc } from '@yozora/ast-util'
import {
  calcDefinitionMap,
  calcFootnoteDefinitionMap,
  calcHeadingToc,
  traverseAst,
} from '@yozora/ast-util'
import { parseMarkdown } from '../parser'
import type { IMarkdownImageItem, INodeRendererMap } from '../types'

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
  public readonly toc$: Computed<IHeadingToc>
  public readonly definitionMap$: Computed<Readonly<Record<string, Definition>>>
  public readonly footnoteDefinitionMap$: Computed<Readonly<Record<string, FootnoteDefinition>>>
  public readonly images$: Computed<ReadonlyArray<IMarkdownImageItem>>

  public readonly rendererMap$: State<Readonly<INodeRendererMap>>
  public readonly showCodeLineno$: State<boolean>
  public readonly themeScheme$: State<string>

  protected readonly presetDefinitionMap: Readonly<Record<string, Definition>>
  protected readonly presetFootnoteDefinitionMap: Readonly<Record<string, FootnoteDefinition>>

  constructor(props: IMarkdownViewModelProps) {
    super()

    const {
      ast: initialAst,
      presetDefinitionMap,
      presetFootnoteDefinitionMap,
      rendererMap,
      showCodeLineno,
      themeScheme,
    } = props

    const ast$: State<Root> = new State<Root>(initialAst, { equals })
    const toc$ = Computed.fromObservables([ast$], ([ast]): IHeadingToc => {
      const toc: IHeadingToc = calcHeadingToc(ast, 'heading-')
      return toc
    })
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
    const images$ = Computed.fromObservables(
      [ast$, definitionMap$],
      ([ast, definitionMap]): IMarkdownImageItem[] => {
        const images: IMarkdownImageItem[] = []
        const srcSets: Set<string> = new Set<string>()
        traverseAst(ast as Root, null, node => {
          switch (node.type) {
            case ImageType: {
              const { alt, url } = node as Image
              if (!srcSets.has(url)) {
                srcSets.add(url)
                images.push({ src: url, alt })
              }
              break
            }
            case ImageReferenceType: {
              const { alt, identifier } = node as ImageReference
              const definition: Definition | undefined = (
                definitionMap as Record<string, Definition>
              )[identifier]
              const url: string | undefined = definition?.url
              if (url && !srcSets.has(url)) {
                srcSets.add(url)
                images.push({ alt, src: url })
              }
              break
            }
            default:
          }
        })
        srcSets.clear()
        return images
      },
    )

    this.ast$ = ast$
    this.toc$ = toc$
    this.definitionMap$ = definitionMap$
    this.footnoteDefinitionMap$ = footnoteDefinitionMap$
    this.images$ = images$

    this.rendererMap$ = new State(rendererMap)
    this.showCodeLineno$ = new State<boolean>(showCodeLineno)
    this.themeScheme$ = new State<string>(themeScheme)

    this.presetDefinitionMap = presetDefinitionMap
    this.presetFootnoteDefinitionMap = presetFootnoteDefinitionMap
  }

  public setContent = (ast: Root): void => {
    this.ast$.next(ast)
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
