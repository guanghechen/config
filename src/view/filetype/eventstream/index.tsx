import React from 'react'
import { useFileResult } from '@/hook/useFileResult'
import type { IEventStreamFileData } from '@/util/fetch'
import { Composer } from './Composer'
import { EventStreamProvider } from './context/Provider'

interface IProps {
  readonly workspace: string | null
  readonly filepath: string | null
  readonly filepathDirtyTick: number
  readonly mainScrollableContainer: HTMLDivElement | null
}

const EventStreamView: React.FC<IProps> = props => {
  const { workspace, filepath, filepathDirtyTick, mainScrollableContainer } = props

  const { data, error } = useFileResult<IEventStreamFileData>(
    workspace,
    filepath,
    filepathDirtyTick,
  )

  return (
    <div className="w-full pt-8">
      {!!error && (
        <div className="relative mb-12 flex-none bg-gray-100 px-2 py-1.5 text-base text-red-500 dark:bg-gray-800 dark:text-red-400">
          <code>error: {String(error)}</code>
        </div>
      )}
      {!!data && (
        <div className="relative w-full">
          <EventStreamProvider content={data?.content}>
            <Composer mainScrollableContainer={mainScrollableContainer} />
          </EventStreamProvider>
        </div>
      )}
    </div>
  )
}

EventStreamView.displayName = 'EventStreamView'

export default React.memo(EventStreamView, () => true)

// Export components, hooks, types and utils for reuse
export { EventStreamProvider } from './context/Provider'
export { Composer as EventStreamComposer } from './Composer'
export { EventStreamContainer } from './container/Composer'
export { useEventStreamContext, useEventStreamViewViewModel } from './context/hook'
export { usePersistedChainPaths } from './hook/usePersistedChainPaths'
export { useScrollToTop } from './hook/useScrollToTop'
export type { IEventStreamEvent, IChainPath, DisplayMode } from './utils'
export {
  parseEventStream,
  parseJsonData,
  extractValueFromPath,
  getPathColor,
  getPathColorClasses,
} from './utils'
