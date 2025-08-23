import React from 'react'
import { Composer } from './Composer'
import { TextViewProvider } from './context'

interface IProps {
  readonly content: string | null
  readonly contentError: string | null
}

export class TextView extends React.PureComponent<IProps> {
  public static readonly displayName = 'TextView'

  public override render(): React.ReactElement {
    const { content, contentError } = this.props

    return (
      <TextViewProvider content={content} contentError={contentError}>
        <Composer />
      </TextViewProvider>
    )
  }
}
