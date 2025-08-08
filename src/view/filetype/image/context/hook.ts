import { useStateValue } from '@guanghechen/react-viewmodel'
import React from 'react'
import { ImageViewContextType } from './context'
import type { IImageViewPosition } from './types'
import type { ImageViewViewModel } from './viewmodel'

export const useImageViewViewModel = (): ImageViewViewModel => {
  const context = React.useContext(ImageViewContextType)
  return context.viewmodel
}

// Alias for backwards compatibility
export const useImageViewModel = useImageViewViewModel

export const useImageViewState = (): {
  workspace: string | null
  filepath: string | null
  scale: number
  rotation: number
  position: IImageViewPosition
} => {
  const viewmodel = useImageViewViewModel()
  return {
    workspace: useStateValue(viewmodel.workspace$),
    filepath: useStateValue(viewmodel.filepath$),
    scale: useStateValue(viewmodel.scale$),
    rotation: useStateValue(viewmodel.rotation$),
    position: useStateValue(viewmodel.position$),
  }
}

// Alias for backwards compatibility
export const useImageState = useImageViewState

export const useImageViewActions = (): {
  setScale: (scale: number | ((prev: number) => number)) => void
  setRotation: (rotation: number | ((prev: number) => number)) => void
  setPosition: (
    position: IImageViewPosition | ((prev: IImageViewPosition) => IImageViewPosition),
  ) => void
} => {
  const viewmodel = useImageViewViewModel()

  const setScale = React.useCallback(
    (scale: number | ((prev: number) => number)) => {
      const newScale = typeof scale === 'function' ? scale(viewmodel.scale$.getSnapshot()) : scale
      viewmodel.scale$.next(newScale)
    },
    [viewmodel],
  )

  const setRotation = React.useCallback(
    (rotation: number | ((prev: number) => number)) => {
      const newRotation =
        typeof rotation === 'function' ? rotation(viewmodel.rotation$.getSnapshot()) : rotation
      viewmodel.rotation$.next(newRotation)
    },
    [viewmodel],
  )

  const setPosition = React.useCallback(
    (position: IImageViewPosition | ((prev: IImageViewPosition) => IImageViewPosition)) => {
      const newPosition =
        typeof position === 'function' ? position(viewmodel.position$.getSnapshot()) : position
      viewmodel.position$.next(newPosition)
    },
    [viewmodel],
  )

  return {
    setScale,
    setRotation,
    setPosition,
  }
}

// Alias for backwards compatibility
export const useImageActions = useImageViewActions
