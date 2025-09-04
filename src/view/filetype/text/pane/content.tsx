import { useStateValue } from '@guanghechen/react-viewmodel'
import React from 'react'
import type { ITextTransformedNode } from '@/shared/types'
import { ContentModeEnum, useTextViewViewModel } from '../context'
import { ContentGraph } from './content-graph'
import { ContentList } from './content-list'
import { ContentPlain } from './content-plain'

const ContentPaneMain: React.FC = () => {
  const viewmodel = useTextViewViewModel()
  const contentMode: ContentModeEnum = useStateValue(viewmodel.contentMode$)
  const records: ITextTransformedNode[] = useStateValue(viewmodel.records$)

  if (records.length > 0) {
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
    <div className="box-border size-full">
      <ContentPaneMain />
    </div>
  )
}

ContentPane.displayName = 'TextViewContentPane'
