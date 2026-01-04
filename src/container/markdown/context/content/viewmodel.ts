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
import type { IMarkdownImageItem } from '../../types'
import type { MarkdownTopViewModel } from '../top'

interface IProps {
  /**
   * Markdown texts.
   */
  readonly ast: Root
  /**
   * Markdown top viewmodel
   */
  readonly top: MarkdownTopViewModel
}

export class MarkdownContentViewModel extends ViewModel {
  public readonly ast$: State<Root>
  public readonly toc$: Computed<IHeadingToc>
  public readonly definitionMap$: Computed<Readonly<Record<string, Definition>>>
  public readonly footnoteDefinitionMap$: Computed<Readonly<Record<string, FootnoteDefinition>>>
  public readonly images$: Computed<ReadonlyArray<IMarkdownImageItem>>

  constructor(props: IProps) {
    super()

    const { ast: initialAst, top } = props

    const ast$: State<Root> = new State<Root>(initialAst, { equals })
    const toc$ = Computed.fromObservables([ast$], ([ast]): IHeadingToc => {
      const toc: IHeadingToc = calcHeadingToc(ast, 'heading-')
      return toc
    })
    const definitionMap$ = Computed.fromObservables(
      [ast$],
      ([ast]): Readonly<Record<string, Definition>> => {
        const presetDefinitions: Definition[] = Object.values({
          ...top.presetDefinitionMap,
        })
        const { root, definitionMap } = calcDefinitionMap(ast, undefined, presetDefinitions)
        ast$.next(root)
        return definitionMap
      },
    )
    const footnoteDefinitionMap$ = Computed.fromObservables(
      [ast$],
      ([ast]): Readonly<Record<string, FootnoteDefinition>> => {
        const presetFootnoteDefinitions: FootnoteDefinition[] = Object.values({
          ...top.presetFootnoteDefinitionMap,
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
  }
}
