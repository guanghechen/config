import React from 'react'
import type { IMarkdownFileData } from '@/shared/types/api'
import { Composer } from './Composer'
import { MarkdownViewProvider } from './context'

interface IProps {
  readonly data: IMarkdownFileData | null
  readonly dataError: string | null
  readonly storageKeyScope: string
}

export class MarkdownView extends React.PureComponent<IProps> {
  public static readonly displayName = 'MarkdownView'

  public override render(): React.ReactElement {
    const { data, dataError, storageKeyScope } = this.props

    return (
      <MarkdownViewProvider data={data} dataError={dataError} storageKeyScope={storageKeyScope}>
        <Composer />
      </MarkdownViewProvider>
    )
  }
}
