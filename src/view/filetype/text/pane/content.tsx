import { useStateValue } from '@guanghechen/react-viewmodel'
import React from 'react'
import type { ITextTransformedNode } from '@/shared/types'
import { ContentMode } from '../container/ContentMode'
import { ContentModeEnum, useTextViewViewModel } from '../context'
import { ContentGraph } from './content-graph'
import { ContentList } from './content-list'
import { ContentPlain } from './content-plain'

const ContentPaneHeader: React.FC = () => {
  const viewmodel = useTextViewViewModel()
  const contentMode: ContentModeEnum = useStateValue(viewmodel.contentMode$)
  const expandTick: number = useStateValue(viewmodel.expandTick$)
  const records: ITextTransformedNode[] | null = useStateValue(viewmodel.records$)
  const expanded: boolean = expandTick % 2 === 0

  return (
    <div className="box-border sticky top-0 z-50 px-4 flex justify-start items-center gap-2 flex-none h-12 bg-gray-50 dark:bg-gray-900">
      <ContentMode />
      {contentMode === ContentModeEnum.LIST && records && (
        <button
          className="group flex h-8 select-none cursor-pointer items-center gap-2 rounded-lg bg-white/80 px-3 py-1.5 text-sm font-medium shadow-sm backdrop-blur-sm transition-all duration-200 hover:bg-white/90 hover:shadow-lg focus:outline-none focus:ring-2 focus:ring-indigo-500/50 dark:bg-gray-900/80 dark:hover:bg-gray-900/90 dark:focus:ring-indigo-400/50"
          onClick={() => viewmodel.expandTick$.setState(tick => tick + 1)}
          title={expanded ? 'Collapse All' : 'Expand All'}
        >
          <div className="flex items-center gap-1.5 text-gray-700 dark:text-gray-300">
            <span>{expanded ? 'Collapse All' : 'Expand All'}</span>
          </div>
        </button>
      )}
      <div className="box-border flex items-center justify-between">
        <span className="text-lg font-semibold text-gray-800 dark:text-gray-200">
          Records ({records?.length ?? 0})
        </span>
      </div>
    </div>
  )
}
ContentPaneHeader.displayName = 'TextViewContentPaneHeader'

const ContentPaneMain: React.FC = () => {
  const viewmodel = useTextViewViewModel()
  const contentMode: ContentModeEnum = useStateValue(viewmodel.contentMode$)
  const records: ITextTransformedNode[] | null = useStateValue(viewmodel.records$)

  if (records) {
    switch (contentMode) {
      case ContentModeEnum.LIST: {
        return <ContentList />
      }
      case ContentModeEnum.GRAPH:
        return <ContentGraph />
      default:
        return <ContentPlain />
    }
  }

  return <ContentPlain />
}
ContentPaneMain.displayName = 'TextViewContentPaneMain'

export const ContentPane: React.FC = () => {
  return (
    <React.Fragment>
      <ContentPaneHeader />
      <div className="box-border w-full flex-auto">
        <ContentPaneMain />
      </div>
    </React.Fragment>
  )
}

ContentPane.displayName = 'TextViewContentPane'
