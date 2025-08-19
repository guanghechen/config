import React from 'react'
import { useSingleton } from '@/hook/useSingleton'
import type { IUnknownViewContext } from './context'
import { UnknownViewContextType } from './context'
import type { ModeEnum } from './types'
import { UnknownViewViewModel } from './viewmodel'

interface IProps {
  readonly workspace: string | null
  readonly filepath: string
  readonly filepathDirtyTick: number
  readonly placeholder?: boolean
  readonly mode?: ModeEnum
  readonly children: React.ReactNode
}

export const UnknownViewProvider: React.FC<IProps> = props => {
  const { filepath, filepathDirtyTick, placeholder, mode, children } = props
  const viewmodel: UnknownViewViewModel | null = useSingleton<UnknownViewViewModel>(() => {
    return new UnknownViewViewModel({ placeholder })
  })
  const context: IUnknownViewContext | null = React.useMemo<IUnknownViewContext | null>(
    () => (viewmodel ? { viewmodel } : null),
    [viewmodel],
  )

  if (!viewmodel || !context) return <React.Fragment />

  return (
    <React.Fragment>
      <UnknownViewContextType.Provider value={context}>{children}</UnknownViewContextType.Provider>
      <SideEffect
        viewmodel={viewmodel}
        placeholder={placeholder}
        filepath={filepath}
        filepathDirtyTick={filepathDirtyTick}
        mode={mode}
      />
    </React.Fragment>
  )
}

UnknownViewProvider.displayName = 'UnknownViewProvider'

// /////////////////////////////////////////////////////////////////////////////////////////////////

interface ISideEffectProps {
  readonly viewmodel: UnknownViewViewModel
  readonly filepath: string
  readonly filepathDirtyTick: number
  readonly placeholder?: boolean
  readonly mode?: ModeEnum
}

const SideEffect: React.FC<ISideEffectProps> = props => {
  const { viewmodel, filepath, placeholder, mode } = props

  React.useEffect(() => {
    if (viewmodel.disposed) return
    viewmodel.placeholder$.next(placeholder ?? true)
  }, [viewmodel, placeholder])

  React.useEffect(() => {
    if (viewmodel.disposed) return
    viewmodel.filepath$.next(filepath)
  }, [viewmodel, filepath])

  React.useEffect(() => {
    if (viewmodel.disposed) return
    viewmodel.mode$.next(mode ?? viewmodel.mode$.getSnapshot())
  }, [viewmodel, mode])

  return <React.Fragment />
}

SideEffect.displayName = 'UnknownViewSideEffect'
