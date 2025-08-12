import { Computed } from '@guanghechen/react-viewmodel'
import React from 'react'
import type { ISvgViewContext } from './context'
import { SvgViewContextType } from './context'
import type { ISvgViewData, ISvgViewPosition } from './types'
import { SvgViewViewModel } from './viewmodel'

const storageKey: string = '@guanghechen/yozora/svg-view'

interface IProps {
  readonly workspace: string | null
  readonly filepath: string
  readonly scale?: number
  readonly rotation?: number
  readonly position?: ISvgViewPosition
  readonly children: React.ReactNode
}

export const SvgViewProvider: React.FC<IProps> = props => {
  const { workspace, filepath, scale, rotation, position, children } = props
  const [viewmodel] = React.useState<SvgViewViewModel>(() => {
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
  readonly scale?: number
  readonly rotation?: number
  readonly position?: ISvgViewPosition
}

const SideEffect: React.FC<ISideEffectProps> = props => {
  const { viewmodel, workspace, filepath, scale, rotation, position } = props

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
    viewmodel.workspace$.next(workspace)
  }, [viewmodel.workspace$, workspace])

  React.useEffect(() => {
    viewmodel.filepath$.next(filepath)
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

SideEffect.displayName = 'SvgViewSideEffect'
