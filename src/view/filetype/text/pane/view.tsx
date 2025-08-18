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

const ViewPaneContent: React.FC<IProps> = props => {
  const { content, viewMode, transformedNodes, columns } = props

  const siteVM = useSiteViewmodel()
  const theme: SiteTheme = useStateValue(siteVM.theme$)

  const viewmodel = useTextViewViewModel()
  const chainPaths: IChainPath[] = useStateValue(viewmodel.chainPaths$)
  const expandTick: number = useStateValue(viewmodel.expandTick$)
  const [displayMode, setDisplayMode] = React.useState<'inline' | 'lines'>('lines')

  const handleChainPathsChange = React.useCallback(
    (newChainPaths: IChainPath[]) => {
      viewmodel.chainPaths$.next(newChainPaths)
    },
    [viewmodel],
  )

  if (transformedNodes) {
    switch (viewMode) {
      case ViewModeEnum.LIST: {
        return (
          <div className="box-border flex h-full flex-col gap-4">
            <div className="box-border flex flex-col justify-between gap-2 flex-none">
              <div className="box-border text-lg font-semibold text-gray-800 dark:text-gray-200">
                Transformed Nodes ({transformedNodes.length})
              </div>
              <MultiPathInput
                chainPaths={chainPaths}
                onChange={handleChainPathsChange}
                displayMode={displayMode}
                onDisplayModeChange={setDisplayMode}
                placeholder="Add JSON paths for transform nodes (e.g., .data.type)"
              />
            </div>
            <div
              className={cn(
                'box-border flex-auto overflow-auto flex flex-col gap-4',
                PRESET_CLASSES.scrollbar,
              )}
            >
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
        )
      }
      case ViewModeEnum.GRAPH:
        return (
          <div className="box-border h-full">
            <DagGraph
              data={transformNodesToGraphData(transformedNodes)}
              theme={theme === SiteTheme.DARKEN ? 'dark' : 'light'}
            />
          </div>
        )
      default:
    }
  }

  return (
    <div className="box-border h-full">
      <div
        className={cn('box-border flex-1', PRESET_CLASSES.scrollbar, {
          'p-2 overflow-auto h-full': columns > 1,
          'p-8': columns === 1,
        })}
      >
        <pre className="font-mono-maple whitespace-pre-wrap break-words text-sm leading-relaxed text-gray-800 dark:text-gray-200">
          {content}
        </pre>
      </div>
    </div>
  )
}

export const ViewPane: React.FC<IProps> = props => {
  const { content, viewMode, transformedNodes, columns } = props

  const viewmodel = useTextViewViewModel()
  const expandTick: number = useStateValue(viewmodel.expandTick$)

  const handleExpandAll = React.useCallback(() => {
    viewmodel.expandTick$.setState(tick => tick + 1)
  }, [viewmodel])

  const isExpanded = expandTick % 2 === 0

  return (
    <div className="box-border relative size-full flex flex-col gap-4 p-4">
      <div className="box-border flex justify-start items-center gap-2 flex-none h-8">
        <ViewModeDropdown />
        {viewMode === ViewModeEnum.LIST && transformedNodes && (
          <button
            onClick={handleExpandAll}
            className="px-3 py-1 text-sm font-medium text-blue-600 bg-blue-50 hover:bg-blue-100 rounded-md transition-colors dark:text-blue-400 dark:bg-blue-900/20 dark:hover:bg-blue-900/40"
          >
            {isExpanded ? 'Collapse All' : 'Expand All'}
          </button>
        )}
      </div>
      <div className="box-border flex-auto h-[calc(100% - 2rem)]">
        <ViewPaneContent
          content={content}
          columns={columns}
          transformedNodes={transformedNodes}
          viewMode={viewMode}
        />
      </div>
    </div>
  )
}

ViewPane.displayName = 'TextViewPane'
