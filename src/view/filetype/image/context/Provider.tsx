import React from 'react'
import { ImageViewContextType } from './context'
import type { IImageViewViewModelProps } from './viewmodel'
import { ImageViewViewModel } from './viewmodel'

interface IProps extends IImageViewViewModelProps {
  readonly children: React.ReactNode
}

export const ImageProvider: React.FC<IProps> = ({ children, ...viewModelProps }) => {
  const viewmodel = React.useMemo(() => new ImageViewViewModel(viewModelProps), [viewModelProps])

  const value = React.useMemo(
    () => ({
      viewmodel,
    }),
    [viewmodel],
  )

  return <ImageViewContextType.Provider value={value}>{children}</ImageViewContextType.Provider>
}

// Keep the old name for backwards compatibility
export const ImageViewProvider = ImageProvider
