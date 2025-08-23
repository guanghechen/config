import React from 'react'
import { Composer } from './Composer'
import { ImageViewProvider } from './context'

interface IProps {
  readonly url: string | null
}

export class ImageView extends React.PureComponent<IProps> {
  public static readonly displayName = 'ImageView'

  public override render(): React.ReactElement {
    const { url } = this.props

    return (
      <ImageViewProvider url={url}>
        <Composer />
      </ImageViewProvider>
    )
  }
}
