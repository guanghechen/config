import React from 'react'
import { Composer } from './Composer'
import { ImageViewProvider } from './context'

interface IProps {
  readonly workspace: string | null
  readonly filepath: string | null
  readonly filepathDirtyTick: number
}

export class ImageView extends React.PureComponent<IProps> {
  public static readonly displayName = 'ImageView'

  public override render(): React.ReactElement {
    const { filepath, workspace } = this.props

    if (!filepath) {
      return (
        <div className="relative size-full flex items-center">
          <div className="text-center text-gray-500 dark:text-gray-400">No file specified</div>
        </div>
      )
    }

    return (
      <ImageViewProvider workspace={workspace} filepath={filepath}>
        <div className="relative size-full">
          <Composer />
        </div>
      </ImageViewProvider>
    )
  }
}
