import { useViewModel } from '@guanghechen/react-viewmodel'
import React from 'react'
import { usePersistAsync } from '@/hook/usePersistAsync'
import type { IImageFileData } from '@/shared/types/api'
import { universalStorage } from '@/util/storage'
import type { IImageViewContext } from './context'
import { ImageViewContextType } from './context'
import type { IImageViewData, IImageViewPosition, ModeEnum } from './types'
import { ImageViewViewModel } from './viewmodel'

interface IProps {
  readonly url: string | null
  readonly mode?: ModeEnum
  readonly scale?: number
  readonly rotation?: number
  readonly position?: IImageViewPosition
  readonly storageKeyScope: string
  readonly children: React.ReactNode
}

export const ImageViewProvider: React.FC<IProps> = props => {
  const { url, mode, scale, rotation, position, storageKeyScope, children } = props
  const storageKey = `${storageKeyScope}/filetype/image`
  const viewmodel: ImageViewViewModel | null = useViewModel<ImageViewViewModel>(async () => {
    const rawViewData = await universalStorage.getContext(storageKey)
    const viewData: IImageViewData = ImageViewViewModel.normalize(rawViewData)
    return new ImageViewViewModel({
      mode: mode ?? viewData.mode,
      scale: scale ?? viewData.scale,
      rotation: rotation ?? viewData.rotation,
      position: position ?? viewData.position,
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
        url={url}
        mode={mode}
        scale={scale}
        rotation={rotation}
        position={position}
        storageKey={storageKey}
      />
    </React.Fragment>
  )
}

ImageViewProvider.displayName = 'ImageViewProvider'

// /////////////////////////////////////////////////////////////////////////////////////////////////

interface ISideEffectProps {
  readonly viewmodel: ImageViewViewModel
  readonly url: string | null
  readonly mode?: ModeEnum
  readonly scale?: number
  readonly rotation?: number
  readonly position?: IImageViewPosition
  readonly storageKey: string
}

const SideEffect: React.FC<ISideEffectProps> = props => {
  const { viewmodel, url, mode, scale, rotation, position, storageKey } = props

  usePersistAsync(viewmodel, storageKey, [
    viewmodel.mode$,
    viewmodel.scale$,
    viewmodel.rotation$,
    viewmodel.position$,
  ])
  useSyncProps(viewmodel, mode, scale, rotation, position)
  useImageLoader(viewmodel, url)

  return <React.Fragment />
}

SideEffect.displayName = 'ImageViewSideEffect'

// /////////////////////////////////////////////////////////////////////////////////////////////////

const useSyncProps = (
  viewmodel: ImageViewViewModel,
  mode: ModeEnum | undefined,
  scale: number | undefined,
  rotation: number | undefined,
  position: IImageViewPosition | undefined,
): void => {
  React.useEffect(() => {
    if (viewmodel.disposed) return
    viewmodel.mode$.next(mode ?? viewmodel.mode$.getSnapshot())
  }, [viewmodel, mode])

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
}

const useImageLoader = (viewmodel: ImageViewViewModel, url: string | null): void => {
  React.useEffect(() => {
    if (viewmodel.disposed) return

    if (!url) {
      viewmodel.data$.next(null)
      viewmodel.literalContent$.next(null)
      return
    }

    // Just store the URL - no actual content loading
    const imageData: IImageFileData = { url }
    viewmodel.data$.next(imageData)

    // Clear literal cache when URL changes
    viewmodel.literalContent$.next(null)
  }, [viewmodel, url])
}
