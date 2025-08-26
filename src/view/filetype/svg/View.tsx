import React from 'react'
import { Composer } from './Composer'
import { SvgViewProvider } from './context'

interface IProps {
  readonly content: string | null
  readonly contentError: string | null
  readonly storageKeyScope: string
}

export class SvgView extends React.PureComponent<IProps> {
  public static readonly displayName = 'SvgView'

  public override render(): React.ReactElement {
    const { content, contentError, storageKeyScope } = this.props

    return (
      <SvgViewProvider
        content={content}
        contentError={contentError}
        storageKeyScope={storageKeyScope}
      >
        <Composer />
      </SvgViewProvider>
    )
  }
}
