import { Computed } from '@guanghechen/react-viewmodel'
import React from 'react'
import { useSingleton } from '@/hook/useSingleton'
import type { IImageViewContext } from './context'
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
  const viewmodel: ImageViewViewModel | null = useSingleton<ImageViewViewModel>(() => {
    const initialData: Partial<IImageViewData> = JSON.parse(
      window.localStorage.getItem(storageKey) || '{}',
    )
    return ImageViewViewModel.fromData({
      scale: scale ?? initialData.scale,
      rotation: rotation ?? initialData.rotation,
      position: position ?? initialData.position,
    })
  })
  const context: IImageViewContext | null = React.useMemo<IImageViewContext | null>(
    () => (viewmodel ? { viewmodel } : null),
    [viewmodel],
  )

  if (!viewmodel || !context) return <React.Fragment />

  return (
    <React.Fragment>
      <ImageViewContextType.Provider value={context}>{children}</ImageViewContextType.Provider>
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
    if (viewmodel.disposed) return
    viewmodel.workspace$.next(workspace ?? null)
  }, [viewmodel, workspace])

  React.useEffect(() => {
    if (viewmodel.disposed) return
    viewmodel.filepath$.next(filepath ?? null)
  }, [viewmodel, filepath])

  React.useEffect(() => {
    if (viewmodel.disposed) return
    viewmodel.scale$.next(scale ?? viewmodel.scale$.getSnapshot())
  }, [viewmodel, scale])

  React.useEffect(() => {
    if (viewmodel.disposed) return
    viewmodel.rotation$.next(rotation ?? viewmodel.rotation$.getSnapshot())
  }, [viewmodel, rotation])

  React.useEffect(() => {
    if (viewmodel.disposed) return
    viewmodel.position$.next(position ?? viewmodel.position$.getSnapshot())
  }, [viewmodel, position])

  return <React.Fragment />
}

SideEffect.displayName = 'ImageViewSideEffect'
