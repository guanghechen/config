import React from 'react'
import type { ImageViewViewModel } from './viewmodel'

export interface IImageViewContext {
  readonly viewmodel: ImageViewViewModel
}

export const ImageViewContextType = React.createContext<IImageViewContext>({
  viewmodel: null as unknown as ImageViewViewModel,
})

export const useImageViewViewModel = (): ImageViewViewModel => {
  const context = React.useContext(ImageViewContextType)
  return context.viewmodel
}
