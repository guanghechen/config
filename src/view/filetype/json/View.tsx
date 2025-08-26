import React from 'react'
import { Composer } from './Composer'
import { JsonViewProvider } from './context'

interface IProps {
  readonly content: string | null
  readonly contentError: string | null
  readonly storageKeyScope: string
}

export class JsonView extends React.PureComponent<IProps> {
  public static readonly displayName = 'JsonView'

  public override render(): React.ReactElement {
    const { content, contentError, storageKeyScope } = this.props

    return (
      <JsonViewProvider
        content={content}
        contentError={contentError}
        storageKeyScope={storageKeyScope}
      >
        <Composer />
      </JsonViewProvider>
    )
  }
}
