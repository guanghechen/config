import { useStateValue } from '@guanghechen/react-viewmodel'
import cn from 'clsx'
import React from 'react'
import { DagGraph, transformNodesToGraphData } from '@/component/graph/dag'
import { SiteTheme, useSiteViewmodel } from '@/context/site'
import { PRESET_CLASSES } from '@/shared/constant'
import type { ITextTransformedNode } from '@/shared/types'
import { ListItemCard } from '../container/ListItemCard'
import { MultiPathInput } from '../container/MultiPathInput'
import { ViewModeDropdown } from '../container/ViewModeDropdown'
import { ViewModeEnum, useTextViewViewModel } from '../context'
import type { IChainPath } from '../context'

interface IProps {
  readonly content: string
  readonly viewMode: ViewModeEnum
  readonly transformedNodes: ITextTransformedNode[] | null
  readonly columns: number
}

export const ViewPane: React.FC<IProps> = props => {
  const { content, viewMode, transformedNodes, columns } = props
  const siteVM = useSiteViewmodel()
  const theme: SiteTheme = useStateValue(siteVM.theme$)

  const viewmodel = useTextViewViewModel()
  const chainPaths: IChainPath[] = useStateValue(viewmodel.chainPaths$)
  const expandTick: number = useStateValue(viewmodel.expandTick$)

  const handleExpandAll = React.useCallback(() => {
    viewmodel.expandTick$.setState(tick => tick + 1)
  }, [viewmodel])

  const isExpanded = expandTick % 2 === 0

  const handleChainPathsChange = React.useCallback(
    (newChainPaths: IChainPath[]) => {
      viewmodel.chainPaths$.next(newChainPaths)
    },
    [viewmodel],
  )

  const [displayMode, setDisplayMode] = React.useState<'inline' | 'lines'>('lines')

  return (
    <div className="box-border p-2 relative size-full flex flex-col">
      <div className="flex items-center gap-2 flex-shrink-0">
        {viewMode === ViewModeEnum.LIST && transformedNodes && (
          <button
            onClick={handleExpandAll}
            className="px-3 py-1 text-sm font-medium text-blue-600 bg-blue-50 hover:bg-blue-100 rounded-md transition-colors dark:text-blue-400 dark:bg-blue-900/20 dark:hover:bg-blue-900/40"
          >
            {isExpanded ? 'Collapse All' : 'Expand All'}
          </button>
        )}
        <ViewModeDropdown />
      </div>
      {viewMode === ViewModeEnum.LIST && transformedNodes ? (
        <div className="flex flex-col gap-2 flex-1">
          <div className="flex items-center justify-between flex-shrink-0">
            <div className="text-lg font-semibold text-gray-800 dark:text-gray-200">
              Transformed Nodes ({transformedNodes.length})
            </div>
          </div>
          <div className="flex-shrink-0">
            <MultiPathInput
              chainPaths={chainPaths}
              onChange={handleChainPathsChange}
              displayMode={displayMode}
              onDisplayModeChange={setDisplayMode}
              placeholder="Add JSON paths for transform nodes (e.g., .data.type)"
            />
          </div>
          <div className={cn('flex-1 overflow-auto flex flex-col gap-4', PRESET_CLASSES.scrollbar)}>
            {transformedNodes.map(node => (
              <ListItemCard
                key={node.uuid}
                transformedNode={node}
                chainPaths={chainPaths}
                expandTick={expandTick}
              />
            ))}
          </div>
        </div>
      ) : (
        <div
          className={cn('box-border flex-1', PRESET_CLASSES.scrollbar, {
            'p-2 overflow-auto': columns > 1,
            'p-8 overflow-auto': columns === 1,
          })}
        >
          {viewMode === ViewModeEnum.GRAPH && transformedNodes ? (
            <div className="box-border w-full h-full min-h-[600px]">
              <DagGraph
                data={transformNodesToGraphData(transformedNodes)}
                theme={theme === SiteTheme.DARKEN ? 'dark' : 'light'}
              />
            </div>
          ) : (
            <pre className="font-mono-maple whitespace-pre-wrap break-words text-sm leading-relaxed text-gray-800 dark:text-gray-200">
              {content}
            </pre>
          )}
        </div>
      )}
    </div>
  )
}

ViewPane.displayName = 'TextViewPane'
