import React from 'react'
import { ImageMain } from './main'
import { ImageTopbar } from './topbar'

interface IProps {
  readonly workspace: string | null
  readonly filepath: string | null
}

export const ImageContainer: React.FC<IProps> = props => {
  const { workspace: _workspace, filepath: _filepath } = props

  return (
    <div className="w-full">
      <div className="h-[4rem] border-b border-gray-200 dark:border-gray-700">
        <ImageTopbar />
      </div>
      <div className="h-[calc(100vh-10rem)] select-none overflow-hidden bg-gray-100 dark:bg-gray-800">
        <ImageMain />
      </div>
    </div>
  )
}

ImageContainer.displayName = 'ImageContainer'
