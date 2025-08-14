import type { Node, Paragraph } from '@yozora/ast'
import { ImageReferenceType, ImageType } from '@yozora/ast'
import React from 'react'
import { NodesRenderer } from '../NodesRenderer'

/**
 * Render `paragraph`.
 *
 * @see https://www.npmjs.com/package/@yozora/ast#paragraph
 * @see https://www.npmjs.com/package/@yozora/tokenizer-paragraph
 */
export class ParagraphRenderer extends React.Component<Paragraph> {
  public static displayName = 'YozoraParagraph'

  public override render(): React.ReactElement {
    const childNodes: Node[] = this.props.children

    // If there are some image / imageReferences element in the paragraph,
    // then wrapper the content with div to avoid the warnings such as:
    //
    //  validateDOMNesting(...): <figure> cannot appear as a descendant of <p>.
    const notValidParagraph: boolean = childNodes.some(
      child => child.type === ImageType || child.type === ImageReferenceType,
    )

    if (notValidParagraph) {
      return (
        <div className="yozora-paragraph flex items-center justify-center py-4 m-0 overflow-hidden hyphens-auto break-words anywhere">
          <NodesRenderer nodes={childNodes} />
        </div>
      )
    }

    return (
      <div className="yozora-paragraph overflow-hidden p-0 mb-5 leading-[1.8] hyphens-auto break-words anywhere [&>:last-child]:mb-0">
        <NodesRenderer nodes={childNodes} />
      </div>
    )
  }

  public override shouldComponentUpdate(nextProps: Readonly<Paragraph>): boolean {
    const props = this.props
    return props.children !== nextProps.children
  }
}
