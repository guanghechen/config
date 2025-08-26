import React from 'react'
import { Composer } from './Composer'
import { ExcalidrawViewProvider } from './context'

interface IProps {
  readonly content: string | null
  readonly contentError: string | null
  readonly onSaveFile?: (content: string) => void
  readonly storageKeyScope: string
}

export class ExcalidrawView extends React.PureComponent<IProps> {
  public static readonly displayName = 'ExcalidrawView'

  public override render(): React.ReactElement {
    const { content, contentError, onSaveFile, storageKeyScope } = this.props

    return (
      <ExcalidrawViewProvider
        content={content}
        contentError={contentError}
        onSaveFile={onSaveFile}
        storageKeyScope={storageKeyScope}
      >
        <Composer />
      </ExcalidrawViewProvider>
    )
  }
}
