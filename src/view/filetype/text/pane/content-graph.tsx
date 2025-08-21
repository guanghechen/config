import { useStateValue } from '@guanghechen/react-viewmodel'
import React from 'react'
import { ReactFlowGraph } from '@/component/graph/reactflow'
import { SiteTheme, useSiteViewmodel } from '@/context/site'
import type { ITextTransformedNode } from '@/shared/types'
import { useTextViewViewModel } from '../context'

export const ContentGraph: React.FC = () => {
  const viewmodel = useTextViewViewModel()
  const transformedNodes: ITextTransformedNode[] = useStateValue(viewmodel.records$)

  const site = useSiteViewmodel()
  const theme: SiteTheme = useStateValue(site.theme$)

  return (
    <div className="box-border size-full overflow-hidden">
      <ReactFlowGraph
        data={transformedNodes}
        theme={theme === SiteTheme.DARKEN ? 'dark' : 'light'}
      />
    </div>
  )
}

ContentGraph.displayName = 'TextViewContentGraph'
