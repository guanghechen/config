import React from 'react'
import { EventStreamViewContextType } from './context'
import { EventStreamViewViewModel, type IEventStreamViewViewModelProps } from './viewmodel'

interface IProps extends IEventStreamViewViewModelProps {
  readonly children: React.ReactNode
}

export const EventStreamViewProvider: React.FC<IProps> = ({ children, ...viewModelProps }) => {
  const viewmodel = React.useMemo(
    () => new EventStreamViewViewModel(viewModelProps),
    [viewModelProps],
  )

  const value = React.useMemo(
    () => ({
      viewmodel,
    }),
    [viewmodel],
  )

  return (
    <EventStreamViewContextType.Provider value={value}>
      {children}
    </EventStreamViewContextType.Provider>
  )
}

EventStreamViewProvider.displayName = 'EventStreamViewProvider'
