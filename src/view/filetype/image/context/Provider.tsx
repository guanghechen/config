import { Computed } from '@guanghechen/react-viewmodel'
import React from 'react'
import { ImageViewContextType } from './context'
import type { IImageViewData, IImageViewPosition } from './types'
import { ImageViewViewModel } from './viewmodel'

const storageKey: string = '#/view/filetype/image'

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
  const [viewmodel] = React.useState<ImageViewViewModel>(() => {
    const initialData: Partial<IImageViewData> = JSON.parse(
      window.localStorage.getItem(storageKey) || '{}',
    )
    return ImageViewViewModel.fromData({
      scale: scale ?? initialData.scale,
      rotation: rotation ?? initialData.rotation,
      position: position ?? initialData.position,
    })
  })
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
    const computed = Computed.fromObservables(
      [viewmodel.scale$, viewmodel.rotation$, viewmodel.position$],
      () => {
        const data: IImageViewData = viewmodel.dump()
        window.localStorage.setItem(storageKey, JSON.stringify(data))
      },
    )
    return (): void => {
      computed.dispose()
    }
  }, [viewmodel])

  React.useEffect(() => {
    viewmodel.workspace$.next(workspace ?? null)
  }, [viewmodel.workspace$, workspace])

  React.useEffect(() => {
    viewmodel.filepath$.next(filepath ?? null)
  }, [viewmodel.filepath$, filepath])

  React.useEffect(() => {
    viewmodel.scale$.next(scale ?? viewmodel.scale$.getSnapshot())
  }, [viewmodel.scale$, scale])

  React.useEffect(() => {
    viewmodel.rotation$.next(rotation ?? viewmodel.rotation$.getSnapshot())
  }, [viewmodel.rotation$, rotation])

  React.useEffect(() => {
    viewmodel.position$.next(position ?? viewmodel.position$.getSnapshot())
  }, [viewmodel.position$, position])

  return <React.Fragment />
}

SideEffect.displayName = 'ImageViewSideEffect'
