import React from 'react'
import { ImageViewViewModel } from './viewmodel'

export interface IImageViewContext {
  readonly viewmodel: ImageViewViewModel
}

export const ImageViewContextType = React.createContext<IImageViewContext>({
  viewmodel: new ImageViewViewModel({
    workspace: null,
    filepath: '/dev/null',
  }),
})

export const useImageViewViewModel = (): ImageViewViewModel => {
  const context = React.useContext(ImageViewContextType)
  return context.viewmodel
}
