import React from 'react'
import { Composer } from './Composer'
import { ImageViewProvider } from './context'

interface IProps {
  readonly url: string | null
  readonly storageKeyScope: string
}

export class ImageView extends React.PureComponent<IProps> {
  public static readonly displayName = 'ImageView'

  public override render(): React.ReactElement {
    const { url, storageKeyScope } = this.props

    return (
      <ImageViewProvider url={url} storageKeyScope={storageKeyScope}>
        <Composer />
      </ImageViewProvider>
    )
  }
}
