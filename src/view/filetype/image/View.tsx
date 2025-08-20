import React from 'react'
import { Composer } from './Composer'
import { ImageViewProvider } from './context'

interface IProps {
  readonly workspace: string | null
  readonly filepath: string
  readonly filepathDirtyTick: number
}

export class ImageView extends React.PureComponent<IProps> {
  public static readonly displayName = 'ImageView'

  public override render(): React.ReactElement {
    const { workspace, filepath, filepathDirtyTick } = this.props

    return (
      <ImageViewProvider
        workspace={workspace}
        filepath={filepath}
        filepathDirtyTick={filepathDirtyTick}
      >
        <Composer />
      </ImageViewProvider>
    )
  }
}
