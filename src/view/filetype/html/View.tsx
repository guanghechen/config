import React from 'react'
import { Composer } from './Composer'
import { HtmlViewProvider } from './context'

interface IProps {
  readonly content: string | null
  readonly contentError: string | null
}

export class HtmlView extends React.PureComponent<IProps> {
  public static readonly displayName = 'HtmlView'

  public override render(): React.ReactElement {
    const { content, contentError } = this.props

    return (
      <HtmlViewProvider content={content} contentError={contentError}>
        <Composer />
      </HtmlViewProvider>
    )
  }
}
