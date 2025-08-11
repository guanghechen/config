import React from 'react'
import type { ISvgViewContext } from './context'
import { SvgViewContextType } from './context'
import type { ISvgViewPosition } from './viewmodel'
import { SvgViewViewModel } from './viewmodel'

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
  const [viewmodel] = React.useState<SvgViewViewModel>(
    () => new SvgViewViewModel({ workspace, filepath, scale, rotation, position }),
  )

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
    viewmodel.workspace$.next(workspace)
  }, [viewmodel.workspace$, workspace])

  React.useEffect(() => {
    viewmodel.filepath$.next(filepath)
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

SideEffect.displayName = 'SvgViewSideEffect'
