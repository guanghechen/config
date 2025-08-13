import React from 'react'
import { useSingleton } from '@/hook/useSingleton'
import type { IUnknownViewContext } from './context'
import { UnknownViewContextType } from './context'
import { UnknownViewViewModel } from './viewmodel'

interface IProps {
  readonly placeholder?: boolean
  readonly children: React.ReactNode
}

export const UnknownViewProvider: React.FC<IProps> = props => {
  const { placeholder, children } = props
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
      <SideEffect viewmodel={viewmodel} placeholder={placeholder} />
    </React.Fragment>
  )
}

UnknownViewProvider.displayName = 'UnknownViewProvider'

// /////////////////////////////////////////////////////////////////////////////////////////////////

interface ISideEffectProps {
  readonly viewmodel: UnknownViewViewModel
  readonly placeholder?: boolean
}

const SideEffect: React.FC<ISideEffectProps> = props => {
  const { viewmodel, placeholder } = props

  React.useEffect(() => {
    if (viewmodel.disposed) return
    viewmodel.placeholder$.next(placeholder ?? true)
  }, [viewmodel, placeholder])

  return <React.Fragment />
}

SideEffect.displayName = 'UnknownViewSideEffect'
