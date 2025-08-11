import React from 'react'
import { JsonViewContextType } from './context'
import type { ModeEnum } from './types'
import { JsonViewViewModel } from './viewmodel'

interface IProps {
  readonly children: React.ReactNode
  readonly mode?: ModeEnum
  readonly content?: string | null
}

export const JsonViewProvider: React.FC<IProps> = ({ children, ...viewModelProps }) => {
  const viewmodel = React.useMemo(() => new JsonViewViewModel(viewModelProps), [viewModelProps])

  const value = React.useMemo(
    () => ({
      viewmodel,
    }),
    [viewmodel],
  )

  return <JsonViewContextType.Provider value={value}>{children}</JsonViewContextType.Provider>
}

JsonViewProvider.displayName = 'JsonViewProvider'
