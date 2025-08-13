import { Computed } from '@guanghechen/react-viewmodel'
import React from 'react'
import { useFileResult } from '@/hook/useFileResult'
import { useSingleton } from '@/hook/useSingleton'
import type { ISvgFileData } from '@/util/fetch'
import type { ISvgViewContext } from './context'
import { SvgViewContextType } from './context'
import type { ISvgViewData, ISvgViewPosition } from './types'
import { SvgViewViewModel } from './viewmodel'

const storageKey: string = '#/view/filetype/svg'

interface IProps {
  readonly workspace: string | null
  readonly filepath: string
  readonly filepathDirtyTick: number
  readonly scale?: number
  readonly rotation?: number
  readonly position?: ISvgViewPosition
  readonly children: React.ReactNode
}

export const SvgViewProvider: React.FC<IProps> = props => {
  const { workspace, filepath, filepathDirtyTick, scale, rotation, position, children } = props
  const viewmodel: SvgViewViewModel = useSingleton<SvgViewViewModel>(() => {
    const initialData: Partial<ISvgViewData> = JSON.parse(
      window.localStorage.getItem(storageKey) || '{}',
    )
    return SvgViewViewModel.fromData({
      scale: scale ?? initialData.scale,
      rotation: rotation ?? initialData.rotation,
      position: position ?? initialData.position,
    })
  })

  const context: ISvgViewContext = React.useMemo<ISvgViewContext>(
    () => ({ viewmodel }),
    [viewmodel],
  )

  return (
    <React.Fragment>
      <SvgViewContextType.Provider value={context}>{children}</SvgViewContextType.Provider>
      <SideEffect
        viewmodel={viewmodel}
        workspace={workspace}
        filepath={filepath}
        filepathDirtyTick={filepathDirtyTick}
        scale={scale}
        rotation={rotation}
        position={position}
      />
    </React.Fragment>
  )
}

SvgViewProvider.displayName = 'SvgViewProvider'

// /////////////////////////////////////////////////////////////////////////////////////////////////

interface ISideEffectProps {
  readonly viewmodel: SvgViewViewModel
  readonly workspace: string | null
  readonly filepath: string
  readonly filepathDirtyTick: number
  readonly scale?: number
  readonly rotation?: number
  readonly position?: ISvgViewPosition
}

const SideEffect: React.FC<ISideEffectProps> = props => {
  const { viewmodel, workspace, filepath, filepathDirtyTick, scale, rotation, position } = props

  const { data, error } = useFileResult<ISvgFileData>(workspace, filepath, filepathDirtyTick)

  React.useEffect(() => {
    if (viewmodel.disposed) return

    if (data) {
      viewmodel.data$.next(data)
      viewmodel.error$.next(null)
    } else if (error) {
      viewmodel.data$.next(null)
      viewmodel.error$.next(typeof error === 'string' ? error : String(error))
    } else {
      viewmodel.data$.next(null)
      viewmodel.error$.next(null)
    }
  }, [data, error, viewmodel])

  React.useEffect(() => {
    const computed = Computed.fromObservables(
      [viewmodel.scale$, viewmodel.rotation$, viewmodel.position$],
      () => {
        const data: ISvgViewData = viewmodel.dump()
        window.localStorage.setItem(storageKey, JSON.stringify(data))
      },
    )
    return (): void => {
      computed.dispose()
    }
  }, [viewmodel])

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

SideEffect.displayName = 'SvgViewSideEffect'
