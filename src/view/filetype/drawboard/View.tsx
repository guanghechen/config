import React from 'react'
import { Composer } from './Composer'
import { DrawboardViewProvider } from './context'

interface IProps {
  readonly content: string | null
  readonly contentError: string | null
  readonly onSaveFile?: (content: string) => void
  readonly storageKeyScope: string
  readonly hideMode?: boolean
}

export class DrawboardView extends React.PureComponent<IProps> {
  public static readonly displayName = 'DrawboardView'

  public override render(): React.ReactElement {
    const { content, contentError, onSaveFile, storageKeyScope, hideMode } = this.props

    return (
      <DrawboardViewProvider
        content={content}
        contentError={contentError}
        onSaveFile={onSaveFile}
        storageKeyScope={storageKeyScope}
      >
        <Composer hideMode={hideMode} />
      </DrawboardViewProvider>
    )
  }
}
