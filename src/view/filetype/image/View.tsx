import React from 'react'
import { Composer } from './Composer'
import { ImageViewProvider } from './context'

export interface ImageContainerProps {
  readonly workspace: string | null
  readonly filepath: string | null
  readonly mainScrollableContainer: HTMLDivElement | null
}

const ImageView: React.FC<ImageContainerProps> = props => {
  const { filepath, workspace, mainScrollableContainer } = props

  return (
    <div className="w-full pt-8">
      <div className="relative w-full">
        <ImageViewProvider workspace={workspace} filepath={filepath}>
          <Composer
            workspace={workspace}
            filepath={filepath}
            mainScrollableContainer={mainScrollableContainer}
          />
        </ImageViewProvider>
      </div>
    </div>
  )
}

ImageView.displayName = 'ImageView'
