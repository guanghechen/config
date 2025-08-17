import React from 'react'
import { Composer } from './Composer'
import { EventStreamViewProvider } from './context'

interface IProps {
  readonly workspace: string | null
  readonly filepath: string | null
  readonly filepathDirtyTick: number
  readonly mainScrollableContainer: HTMLDivElement | null
}

export const EventStreamView: React.FC<IProps> = props => {
  const { workspace, filepath, filepathDirtyTick, mainScrollableContainer } = props

  return (
    <div className="w-full pt-8">
      <EventStreamViewProvider
        workspace={workspace}
        filepath={filepath}
        filepathDirtyTick={filepathDirtyTick}
      >
        <Composer mainScrollableContainer={mainScrollableContainer} />
      </EventStreamViewProvider>
    </div>
  )
}

EventStreamView.displayName = 'EventStreamView'
