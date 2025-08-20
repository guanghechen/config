import { Computed } from '@guanghechen/react-viewmodel'
import React from 'react'
import { toast } from 'react-toastify'
import type { IImageFileData } from '@/hook/api/file'
import { useFileResult } from '@/hook/useFileResult'
import { useSingleton } from '@/hook/useSingleton'
import type { IImageViewContext } from './context'
import { ImageViewContextType } from './context'
import type { IImageViewData, IImageViewPosition, ModeEnum } from './types'
import { ImageViewViewModel } from './viewmodel'

const storageKey: string = '#/view/filetype/image'

interface IProps {
  readonly workspace: string | null
  readonly filepath: string
  readonly filepathDirtyTick: number
  readonly mode?: ModeEnum
  readonly scale?: number
  readonly rotation?: number
  readonly position?: IImageViewPosition
  readonly children: React.ReactNode
}

export const ImageViewProvider: React.FC<IProps> = props => {
  const { workspace, filepath, filepathDirtyTick, mode, scale, rotation, position, children } =
    props
  const viewmodel: ImageViewViewModel | null = useSingleton<ImageViewViewModel>(() => {
    const rawViewData: Partial<IImageViewData> = JSON.parse(
      window.localStorage.getItem(storageKey) || '{}',
    )
    const viewData: IImageViewData = ImageViewViewModel.normalize(rawViewData)
    return new ImageViewViewModel({
      workspace,
      filepath,
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
        workspace={workspace}
        filepath={filepath}
        filepathDirtyTick={filepathDirtyTick}
        mode={mode}
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
  readonly workspace: string | null
  readonly filepath: string
  readonly filepathDirtyTick: number
  readonly mode?: ModeEnum
  readonly scale?: number
  readonly rotation?: number
  readonly position?: IImageViewPosition
}

const SideEffect: React.FC<ISideEffectProps> = props => {
  const { viewmodel, workspace, filepath, filepathDirtyTick, mode, scale, rotation, position } =
    props

  usePersistent(viewmodel)
  useSyncProps(viewmodel, workspace, filepath, mode, scale, rotation, position)
  useData(viewmodel, workspace, filepath, filepathDirtyTick)

  return <React.Fragment />
}

SideEffect.displayName = 'ImageViewSideEffect'

// /////////////////////////////////////////////////////////////////////////////////////////////////

const usePersistent = (viewmodel: ImageViewViewModel): void => {
  React.useEffect(() => {
    const computed = Computed.fromObservables(
      [viewmodel.mode$, viewmodel.scale$, viewmodel.rotation$, viewmodel.position$],
      () => {
        const data: IImageViewData = viewmodel.dump()
        window.localStorage.setItem(storageKey, JSON.stringify(data))
      },
    )
    return (): void => {
      computed.dispose()
    }
  }, [viewmodel])
}

const useSyncProps = (
  viewmodel: ImageViewViewModel,
  workspace: string | null,
  filepath: string,
  mode: ModeEnum | undefined,
  scale: number | undefined,
  rotation: number | undefined,
  position: IImageViewPosition | undefined,
): void => {
  React.useEffect(() => {
    if (viewmodel.disposed) return
    viewmodel.workspace$.next(workspace)
  }, [viewmodel, workspace])

  React.useEffect(() => {
    if (viewmodel.disposed) return
    viewmodel.filepath$.next(filepath)
  }, [viewmodel, filepath])

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

const useData = (
  viewmodel: ImageViewViewModel,
  workspace: string | null,
  filepath: string,
  filepathDirtyTick: number,
): void => {
  const { data, error } = useFileResult<IImageFileData>(workspace, filepath, filepathDirtyTick)

  React.useEffect(() => {
    if (viewmodel.disposed) return

    if (data) {
      viewmodel.content$.next(data)
    } else if (error) {
      viewmodel.content$.next(null)
      toast.error(typeof error === 'string' ? error : String(error))
    } else {
      viewmodel.content$.next(null)
    }
  }, [data, error, viewmodel])
}
