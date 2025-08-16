import { Computed } from '@guanghechen/react-viewmodel'
import React from 'react'
import type { IEventStreamFileData } from '@/hook/api/file'
import { useFileResult } from '@/hook/useFileResult'
import { useSingleton } from '@/hook/useSingleton'
import { parseEventStream } from '../utils'
import type { IEventStreamViewContext } from './context'
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
  const viewmodel: EventStreamViewViewModel | null = useSingleton<EventStreamViewViewModel>(() => {
    const initialData: Partial<IEventStreamViewData> = JSON.parse(
      window.localStorage.getItem(storageKey) || '{}',
    )
    return EventStreamViewViewModel.fromData({
      mode: mode ?? initialData.mode,
      chainPaths: chainPaths ?? initialData.chainPaths,
      displayMode: displayMode ?? initialData.displayMode,
    })
  })
  const context: IEventStreamViewContext | null = React.useMemo<IEventStreamViewContext | null>(
    () => (viewmodel ? { viewmodel } : null),
    [viewmodel],
  )

  if (!viewmodel || !context) return <React.Fragment />

  return (
    <React.Fragment>
      <EventStreamViewContextType.Provider value={context}>
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
    if (viewmodel.disposed) return

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
    if (viewmodel.disposed) return
    viewmodel.mode$.next(mode ?? viewmodel.mode$.getSnapshot())
  }, [viewmodel, mode])

  React.useEffect(() => {
    if (viewmodel.disposed) return
    viewmodel.activeEventIndex$.next(activeEventIndex ?? null)
  }, [viewmodel, activeEventIndex])

  React.useEffect(() => {
    if (viewmodel.disposed) return
    viewmodel.chainPaths$.next(chainPaths ?? viewmodel.chainPaths$.getSnapshot())
  }, [viewmodel, chainPaths])

  React.useEffect(() => {
    if (viewmodel.disposed) return
    viewmodel.displayMode$.next(displayMode ?? viewmodel.displayMode$.getSnapshot())
  }, [viewmodel, displayMode])

  return <React.Fragment />
}

SideEffect.displayName = 'EventStreamViewSideEffect'
