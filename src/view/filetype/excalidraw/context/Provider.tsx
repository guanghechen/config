import React from 'react'
import { ExcalidrawViewContextType } from './context'
import type { IExcalidrawViewViewModelProps } from './viewmodel'
import { ExcalidrawViewViewModel } from './viewmodel'

interface IProps extends IExcalidrawViewViewModelProps {
  readonly children: React.ReactNode
}

export const ExcalidrawProvider: React.FC<IProps> = ({ children, ...viewModelProps }) => {
  const viewmodel = React.useMemo(
    () => new ExcalidrawViewViewModel(viewModelProps),
    [viewModelProps],
  )

  const value = React.useMemo(
    () => ({
      viewmodel,
    }),
    [viewmodel],
  )

  return (
    <ExcalidrawViewContextType.Provider value={value}>
      {children}
    </ExcalidrawViewContextType.Provider>
  )
}

// Keep the old name for backwards compatibility
export const ExcalidrawViewProvider = ExcalidrawProvider
