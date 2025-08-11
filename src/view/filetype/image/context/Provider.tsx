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

export const ImageViewProvider: React.FC<IProps> = props => {
  const { workspace, filepath, scale, rotation, position, children } = props
  const [viewmodel] = React.useState<ImageViewViewModel>(
    () => new ImageViewViewModel({ workspace, filepath, scale, rotation, position }),
  )
  const value = React.useMemo(() => ({ viewmodel }), [viewmodel])

  return (
    <React.Fragment>
      <ImageViewContextType.Provider value={value}>{children}</ImageViewContextType.Provider>
      <SideEffect
        viewmodel={viewmodel}
        workspace={workspace}
        filepath={filepath}
        scale={scale}
        rotation={rotation}
        position={position}
      />
    </React.Fragment>
  )
}

ImageViewProvider.displayName = 'ImageViewProvider'

// /////////////////////////////////////////////////////////////////////////////////////////////////

interface ISideEffectProps {
  readonly viewmodel: ImageViewViewModel
  readonly workspace?: string | null
  readonly filepath?: string | null
  readonly scale?: number
  readonly rotation?: number
  readonly position?: IImageViewPosition
}

const SideEffect: React.FC<ISideEffectProps> = props => {
  const { viewmodel, workspace, filepath, scale, rotation, position } = props

  React.useEffect(() => {
    viewmodel.workspace$.next(workspace ?? null)
  }, [viewmodel.workspace$, workspace])

  React.useEffect(() => {
    viewmodel.filepath$.next(filepath ?? null)
  }, [viewmodel.filepath$, filepath])

  React.useEffect(() => {
    viewmodel.scale$.next(scale ?? 1)
  }, [viewmodel.scale$, scale])

  React.useEffect(() => {
    viewmodel.rotation$.next(rotation ?? 0)
  }, [viewmodel.rotation$, rotation])

  React.useEffect(() => {
    viewmodel.position$.next(position ?? { x: 0, y: 0 })
  }, [viewmodel.position$, position])

  return <React.Fragment />
}

SideEffect.displayName = 'ImageViewSideEffect'
