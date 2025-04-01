import React from 'react'
import { ImageMain } from './main'
import { ImageTopbar } from './topbar'

export interface ImageContainerProps {
  readonly workspace: string | null
  readonly filepath: string | null
}

export const ImageContainer: React.FC<ImageContainerProps> = props => {
  const { filepath, workspace } = props
  const [scale, setScale] = React.useState<number>(1)
  const [rotation, setRotation] = React.useState<number>(0)
  const [position, setPosition] = React.useState<{ x: number; y: number }>({ x: 0, y: 0 })

  return (
    <div className="w-full">
      <div className="h-[4rem] border-b border-gray-200 dark:border-gray-700">
        <ImageTopbar
          scale={scale}
          setPosition={setPosition}
          setRotation={setRotation}
          setScale={setScale}
        />
      </div>
      <div className="h-[calc(100vh-10rem)] select-none overflow-hidden bg-gray-100 dark:bg-gray-800">
        <ImageMain
          workspace={workspace}
          filepath={filepath}
          position={position}
          rotation={rotation}
          scale={scale}
          setPosition={setPosition}
          setScale={setScale}
        />
      </div>
    </div>
  )
}

ImageContainer.displayName = 'ImageContainer'
export default ImageContainer
