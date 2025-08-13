import { Computed } from '@guanghechen/react-viewmodel'
import React from 'react'
import { ViewModelCleanupSideEffect } from '@/container/ViewModelCleanup'
import { useFileResult } from '@/hook/useFileResult'
import type { IEventStreamFileData } from '@/util/fetch'
import { parseEventStream } from '../utils'
import { EventStreamViewContextType } from './context'
import type { DisplayMode, IChainPath, IEventStreamViewData, ModeEnum } from './types'
import { EventStreamViewViewModel } from './viewmodel'

const storageKey: string = '#/view/filetype/eventstream'

interface IProps {
  readonly workspace: string | null
  readonly filepath: string | null
  readonly filepathDirtyTick: number
  readonly content?: string
  readonly mode?: ModeEnum
  readonly activeEventIndex?: number | null
  readonly chainPaths?: IChainPath[]
  readonly displayMode?: DisplayMode
  readonly children: React.ReactNode
}

export const EventStreamViewProvider: React.FC<IProps> = props => {
  const {
    workspace,
    filepath,
    filepathDirtyTick,
    content,
    mode,
    activeEventIndex,
    chainPaths,
    displayMode,
    children,
  } = props
  const [viewmodel] = React.useState<EventStreamViewViewModel>(() => {
    const initialData: Partial<IEventStreamViewData> = JSON.parse(
      window.localStorage.getItem(storageKey) || '{}',
    )
    return EventStreamViewViewModel.fromData({
      mode: mode ?? initialData.mode,
      chainPaths: chainPaths ?? initialData.chainPaths,
      displayMode: displayMode ?? initialData.displayMode,
    })
  })
  const value = React.useMemo(() => ({ viewmodel }), [viewmodel])

  return (
    <React.Fragment>
      <EventStreamViewContextType.Provider value={value}>
        {children}
      </EventStreamViewContextType.Provider>
      <SideEffect
        viewmodel={viewmodel}
        workspace={workspace}
        filepath={filepath}
        filepathDirtyTick={filepathDirtyTick}
        content={content}
        mode={mode}
        activeEventIndex={activeEventIndex}
        chainPaths={chainPaths}
        displayMode={displayMode}
      />
      <ViewModelCleanupSideEffect viewmodel={viewmodel} />
    </React.Fragment>
  )
}

EventStreamViewProvider.displayName = 'EventStreamViewProvider'

// /////////////////////////////////////////////////////////////////////////////////////////////////

interface ISideEffectProps {
  readonly viewmodel: EventStreamViewViewModel
  readonly workspace: string | null
  readonly filepath: string | null
  readonly filepathDirtyTick: number
  readonly content?: string
  readonly mode?: ModeEnum
  readonly activeEventIndex?: number | null
  readonly chainPaths?: IChainPath[]
  readonly displayMode?: DisplayMode
}

const SideEffect: React.FC<ISideEffectProps> = props => {
  const {
    viewmodel,
    workspace,
    filepath,
    filepathDirtyTick,
    content,
    mode,
    activeEventIndex,
    chainPaths,
    displayMode,
  } = props

  const { data, error } = useFileResult<IEventStreamFileData>(
    workspace,
    filepath,
    filepathDirtyTick,
  )

  React.useEffect(() => {
    if (data?.content) {
      viewmodel.content$.next(data.content)

      // Parse eventstream content
      const events = parseEventStream(data.content)
      viewmodel.events$.next(events)
    } else if (error) {
      viewmodel.content$.next('')
      viewmodel.events$.next([])
    } else {
      viewmodel.content$.next(content ?? '')
      if (content) {
        const events = parseEventStream(content)
        viewmodel.events$.next(events)
      } else {
        viewmodel.events$.next([])
      }
    }
  }, [data, error, content, viewmodel])

  React.useEffect(() => {
    const computed = Computed.fromObservables(
      [viewmodel.mode$, viewmodel.chainPaths$, viewmodel.displayMode$],
      () => {
        const data: IEventStreamViewData = viewmodel.dump()
        window.localStorage.setItem(storageKey, JSON.stringify(data))
      },
    )
    return (): void => {
      computed.dispose()
    }
  }, [viewmodel])

  React.useEffect(() => {
    viewmodel.mode$.next(mode ?? viewmodel.mode$.getSnapshot())
  }, [viewmodel.mode$, mode])

  React.useEffect(() => {
    viewmodel.activeEventIndex$.next(activeEventIndex ?? null)
  }, [viewmodel.activeEventIndex$, activeEventIndex])

  React.useEffect(() => {
    viewmodel.chainPaths$.next(chainPaths ?? viewmodel.chainPaths$.getSnapshot())
  }, [viewmodel.chainPaths$, chainPaths])

  React.useEffect(() => {
    viewmodel.displayMode$.next(displayMode ?? viewmodel.displayMode$.getSnapshot())
  }, [viewmodel.displayMode$, displayMode])

  return <React.Fragment />
}

SideEffect.displayName = 'EventStreamViewSideEffect'
