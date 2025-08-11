import React from 'react'
import { EventStreamViewViewModel } from './viewmodel'

export interface IEventStreamViewContext {
  readonly viewmodel: EventStreamViewViewModel
}

export const EventStreamViewContextType = React.createContext<IEventStreamViewContext>({
  viewmodel: new EventStreamViewViewModel(),
})

export const useEventStreamViewViewModel = (): EventStreamViewViewModel => {
  const context = React.useContext(EventStreamViewContextType)
  return context.viewmodel
}
