import React from 'react'
import { Composer } from './Composer'
import { EventStreamViewProvider } from './context'

interface IProps {
  readonly workspace: string | null
  readonly filepath: string | null
  readonly filepathDirtyTick: number
  readonly mainScrollableContainer: HTMLDivElement | null
  readonly topbarVisible: boolean
}

export const EventStreamView: React.FC<IProps> = props => {
  const { workspace, filepath, filepathDirtyTick, mainScrollableContainer, topbarVisible } = props

  return (
    <div className="w-full pt-8">
      <EventStreamViewProvider
        workspace={workspace}
        filepath={filepath}
        filepathDirtyTick={filepathDirtyTick}
      >
        <Composer mainScrollableContainer={mainScrollableContainer} topbarVisible={topbarVisible} />
      </EventStreamViewProvider>
    </div>
  )
}

EventStreamView.displayName = 'EventStreamView'
