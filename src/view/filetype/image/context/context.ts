import React from 'react'
import { ImageViewViewModel } from './viewmodel'

export interface IImageViewContext {
  readonly viewmodel: ImageViewViewModel
}

export const ImageViewContextType = React.createContext<IImageViewContext>({
  viewmodel: new ImageViewViewModel(),
})
