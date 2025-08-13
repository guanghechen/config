import React from 'react'
import { ViewModelCleanupSideEffect } from '@/container/ViewModelCleanup'
import { UnknownViewContextType } from './context'
import { UnknownViewViewModel } from './viewmodel'

interface IProps {
  readonly placeholder?: boolean
  readonly children: React.ReactNode
}

export const UnknownViewProvider: React.FC<IProps> = props => {
  const { placeholder, children } = props
  const [viewmodel] = React.useState<UnknownViewViewModel>(
    () => new UnknownViewViewModel({ placeholder }),
  )
  const value = React.useMemo(() => ({ viewmodel }), [viewmodel])

  return (
    <React.Fragment>
      <UnknownViewContextType.Provider value={value}>{children}</UnknownViewContextType.Provider>
      <SideEffect viewmodel={viewmodel} placeholder={placeholder} />
      <ViewModelCleanupSideEffect viewmodel={viewmodel} />
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
  }, [viewmodel.placeholder$, placeholder])

  return <React.Fragment />
}

SideEffect.displayName = 'UnknownViewSideEffect'
