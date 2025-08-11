import React from 'react'
import { EventStreamViewContextType } from './context'
import type { DisplayMode, IChainPath, ModeEnum } from './types'
import { EventStreamViewViewModel } from './viewmodel'

interface IProps {
  readonly content?: string
  readonly mode?: ModeEnum
  readonly activeEventIndex?: number | null
  readonly expandedEvents?: Set<number>
  readonly chainPaths?: IChainPath[]
  readonly displayMode?: DisplayMode
  readonly children: React.ReactNode
}

export const EventStreamViewProvider: React.FC<IProps> = props => {
  const { content, mode, activeEventIndex, expandedEvents, chainPaths, displayMode, children } =
    props
  const [viewmodel] = React.useState<EventStreamViewViewModel>(
    () =>
      new EventStreamViewViewModel({
        content,
        mode,
        activeEventIndex,
        expandedEvents,
        chainPaths,
        displayMode,
      }),
  )
  const value = React.useMemo(() => ({ viewmodel }), [viewmodel])

  return (
    <EventStreamViewContextType.Provider value={value}>
      {children}
      <SideEffect
        viewmodel={viewmodel}
        content={content}
        mode={mode}
        activeEventIndex={activeEventIndex}
        expandedEvents={expandedEvents}
        chainPaths={chainPaths}
        displayMode={displayMode}
      />
    </EventStreamViewContextType.Provider>
  )
}

EventStreamViewProvider.displayName = 'EventStreamViewProvider'

// /////////////////////////////////////////////////////////////////////////////////////////////////

interface ISideEffectProps {
  readonly viewmodel: EventStreamViewViewModel
  readonly content?: string
  readonly mode?: ModeEnum
  readonly activeEventIndex?: number | null
  readonly expandedEvents?: Set<number>
  readonly chainPaths?: IChainPath[]
  readonly displayMode?: DisplayMode
}

const SideEffect: React.FC<ISideEffectProps> = props => {
  const { viewmodel, content, mode, activeEventIndex, expandedEvents, chainPaths, displayMode } =
    props

  React.useEffect(() => {
    viewmodel.content$.next(content ?? '')
  }, [viewmodel.content$, content])

  React.useEffect(() => {
    viewmodel.mode$.next(mode ?? 1)
  }, [viewmodel.mode$, mode])

  React.useEffect(() => {
    viewmodel.activeEventIndex$.next(activeEventIndex ?? null)
  }, [viewmodel.activeEventIndex$, activeEventIndex])

  React.useEffect(() => {
    viewmodel.expandedEvents$.next(expandedEvents ?? new Set())
  }, [viewmodel.expandedEvents$, expandedEvents])

  React.useEffect(() => {
    viewmodel.chainPaths$.next(chainPaths ?? [])
  }, [viewmodel.chainPaths$, chainPaths])

  React.useEffect(() => {
    viewmodel.displayMode$.next(displayMode ?? 'lines')
  }, [viewmodel.displayMode$, displayMode])

  return <React.Fragment />
}

SideEffect.displayName = 'EventStreamViewSideEffect'
