import React from 'react'
import { ImageViewContextType } from './context'
import type { IImageViewPosition } from './types'
import { ImageViewViewModel } from './viewmodel'

interface IProps {
  readonly workspace?: string | null
  readonly filepath?: string | null
  readonly scale?: number
  readonly rotation?: number
  readonly position?: IImageViewPosition
  readonly children: React.ReactNode
}

export const ImageViewProvider: React.FC<IProps> = ({ children, ...viewModelProps }) => {
  const viewmodel = React.useMemo(() => new ImageViewViewModel(viewModelProps), [viewModelProps])

  const value = React.useMemo(
    () => ({
      viewmodel,
    }),
    [viewmodel],
  )

  return <ImageViewContextType.Provider value={value}>{children}</ImageViewContextType.Provider>
}

ImageViewProvider.displayName = 'ImageViewProvider'
