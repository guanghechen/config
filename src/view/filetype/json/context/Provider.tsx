import React from 'react'
import { JsonViewContextType } from './context'
import type { IJsonViewViewModelProps } from './viewmodel'
import { JsonViewViewModel } from './viewmodel'

interface IProps extends IJsonViewViewModelProps {
  readonly children: React.ReactNode
}

export const JsonProvider: React.FC<IProps> = ({ children, ...viewModelProps }) => {
  const viewmodel = React.useMemo(() => new JsonViewViewModel(viewModelProps), [viewModelProps])

  const value = React.useMemo(
    () => ({
      viewmodel,
    }),
    [viewmodel],
  )

  return <JsonViewContextType.Provider value={value}>{children}</JsonViewContextType.Provider>
}

// Keep the old name for backwards compatibility
export const JsonViewProvider = JsonProvider
