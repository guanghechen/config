import { useStateValue } from '@guanghechen/react-viewmodel'
import React from 'react'
import type { ITextTransformedNode } from '@/shared/types'
import { ViewModeDropdown } from '../container/ViewModeDropdown'
import { ViewModeEnum, useTextViewViewModel } from '../context'
import { ContentGraph } from './content-graph'
import { ContentList } from './content-list'
import { ContentPlain } from './content-plain'

const ContentPaneMain: React.FC = () => {
  const viewmodel = useTextViewViewModel()
  const viewMode: ViewModeEnum = useStateValue(viewmodel.viewMode$)
  const records: ITextTransformedNode[] | null = useStateValue(viewmodel.transformedNodes$)

  if (records) {
    switch (viewMode) {
      case ViewModeEnum.LIST: {
        return <ContentList />
      }
      case ViewModeEnum.GRAPH:
        return <ContentGraph />
      default:
        return <ContentPlain />
    }
  }

  return <ContentPlain />
}
ContentPaneMain.displayName = 'TextViewContentPaneMain'

export const ContentPane: React.FC = () => {
  const viewmodel = useTextViewViewModel()
  const viewMode: ViewModeEnum = useStateValue(viewmodel.viewMode$)
  const records: ITextTransformedNode[] | null = useStateValue(viewmodel.transformedNodes$)
  const expandTick: number = useStateValue(viewmodel.expandTick$)
  const contentError = useStateValue(viewmodel.contentError)

  if (contentError) {
    return (
      <div className="box-border size-full flex justify-center">
        <div className="flex items-center bg-gray-100 text-red-500 dark:bg-gray-800 dark:text-red-400">
          <code>error: {String(contentError)}</code>
        </div>
      </div>
    )
  }

  const isExpanded = expandTick % 2 === 0
  return (
    <React.Fragment>
      <div className="box-border sticky top-0 z-50 px-4 flex justify-start items-center gap-2 flex-none h-12 bg-gray-50 dark:bg-gray-900">
        <ViewModeDropdown />
        {viewMode === ViewModeEnum.LIST && records && (
          <button
            className="px-3 py-1 text-sm font-medium rounded-md transition-colors text-blue-600 bg-blue-50 hover:bg-blue-100 dark:text-blue-400 dark:bg-blue-900/20 dark:hover:bg-blue-900/40"
            onClick={() => viewmodel.expandTick$.setState(tick => tick + 1)}
          >
            {isExpanded ? 'Collapse All' : 'Expand All'}
          </button>
        )}
      </div>
      <div className="box-border flex-auto px-4 pb-8">
        <ContentPaneMain />
      </div>
    </React.Fragment>
  )
}

ContentPane.displayName = 'TextViewContentPane'
