import { useStateValue } from '@guanghechen/react-viewmodel'
import cn from 'clsx'
import React from 'react'
import { PRESET_CLASSES } from '@/shared/constant'
import type { ITextTransformedNode } from '@/shared/types'
import { ListItemCard } from '../container/ListItemCard'
import { MultiPathInput } from '../container/MultiPathInput'
import type { IChainPath } from '../context'
import { useTextViewViewModel } from '../context'

export const ContentList: React.FC = () => {
  const viewmodel = useTextViewViewModel()
  const transformedNodes: ITextTransformedNode[] = useStateValue(viewmodel.transformedNodes$) || []
  const chainPaths: IChainPath[] = useStateValue(viewmodel.chainPaths$)
  const expandTick: number = useStateValue(viewmodel.expandTick$)
  const activeRecordIndex: number | null = useStateValue(viewmodel.activeRecordIndex$)

  const containerRef = React.useRef<HTMLDivElement>(null)

  const [displayMode, setDisplayMode] = React.useState<'inline' | 'lines'>('lines')

  // Autoscroll to active item when activeRecordIndex changes
  React.useEffect(() => {
    if (activeRecordIndex !== null && containerRef.current) {
      const activeItem = containerRef.current.querySelector(
        `[data-content-index="${activeRecordIndex}"]`,
      )
      if (activeItem) {
        activeItem.scrollIntoView({ behavior: 'smooth', block: 'center' })
      }
    }
  }, [activeRecordIndex])
  const handleChainPathsChange = React.useCallback(
    (newChainPaths: IChainPath[]) => {
      viewmodel.chainPaths$.next(newChainPaths)
    },
    [viewmodel],
  )

  return (
    <div className="box-border size-full flex flex-col gap-4">
      <div className="box-border sticky top-12 z-50 flex flex-col justify-between gap-2 flex-none rounded-lg shadow-sm p-4 bg-gray-50 dark:bg-gray-900">
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
        ref={containerRef}
        className={cn(
          'box-border flex-auto overflow-auto flex flex-col gap-4',
          PRESET_CLASSES.scrollbar,
        )}
      >
        {transformedNodes.map((node, index) => (
          <ListItemCard
            key={node.uuid}
            transformedNode={node}
            chainPaths={chainPaths}
            expandTick={expandTick}
            isActive={activeRecordIndex === index}
            data-content-index={index}
          />
        ))}
      </div>
    </div>
  )
}

ContentList.displayName = 'TextViewContentList'
