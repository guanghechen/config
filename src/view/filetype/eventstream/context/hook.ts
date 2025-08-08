import React from 'react'
import { EventStreamViewContextType } from './context'
import type { EventStreamViewViewModel } from './viewmodel'

type EventStreamContextType = React.ContextType<typeof EventStreamViewContextType>

export const useEventStreamViewViewModel = (): EventStreamViewViewModel => {
  const context = React.useContext(EventStreamViewContextType)
  return context.viewmodel
}

export const useEventStreamContext = (): EventStreamContextType => {
  return React.useContext(EventStreamViewContextType)
}
