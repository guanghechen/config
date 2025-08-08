import React from 'react'
import { UnknownViewContextType } from './context'
import { type IUnknownViewViewModelProps, UnknownViewViewModel } from './viewmodel'

interface IProps extends IUnknownViewViewModelProps {
  readonly children: React.ReactNode
}

export const UnknownViewProvider: React.FC<IProps> = ({ children, ...viewModelProps }) => {
  const viewmodel = React.useMemo(() => new UnknownViewViewModel(viewModelProps), [viewModelProps])

  const value = React.useMemo(
    () => ({
      viewmodel,
    }),
    [viewmodel],
  )

  return <UnknownViewContextType.Provider value={value}>{children}</UnknownViewContextType.Provider>
}

UnknownViewProvider.displayName = 'UnknownViewProvider'
