import React from 'react'
import { Composer } from './Composer'
import { ImageProvider } from './context/Provider'

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
        <ImageProvider workspace={workspace} filepath={filepath}>
          <Composer
            workspace={workspace}
            filepath={filepath}
            mainScrollableContainer={mainScrollableContainer}
          />
        </ImageProvider>
      </div>
    </div>
  )
}

ImageView.displayName = 'ImageView'

export default ImageView

// Export components, hooks, types and utils for reuse
export { ImageProvider } from './context/Provider'
export { Composer as ImageComposer } from './Composer'
export { ImageContainer } from './container/ImageContainer'
export { ImageMain } from './container/main'
export { ImageTopbar } from './container/topbar'
export { useImageViewModel } from './context/hook'
export type { IImagePosition } from './context/types'
