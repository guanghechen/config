import { useStateValue } from '@guanghechen/react-viewmodel'
import React from 'react'
import type { ITextTransformConfig, ITextTransformedNode } from '@/shared/types'
import { ContentListItem } from '../container/ContentListItem'
import { MultiPathInput } from '../container/MultiPathInput'
import type { IChainPath } from '../context'
import { useTextViewViewModel } from '../context'
import { chainPathsToStringArray, stringArrayToChainPaths } from '../utils'

export const ContentList: React.FC = () => {
  const viewmodel = useTextViewViewModel()
  const transformedNodes: ITextTransformedNode[] = useStateValue(viewmodel.records$) || []
  const transformConfig: ITextTransformConfig = useStateValue(viewmodel.transformConfig$)
  const chainPaths: IChainPath[] = stringArrayToChainPaths(transformConfig.chainPaths)
  const expandTick: number = useStateValue(viewmodel.expandTick$)
  const activeRecordIndex: number | null = useStateValue(viewmodel.activeRecordIndex$)

  const containerRef = React.useRef<HTMLDivElement>(null)
  const [displayMode, setDisplayMode] = React.useState<'inline' | 'lines'>('inline')

  const handleChainPathsChange = React.useCallback(
    (newChainPaths: IChainPath[]) => {
      const newStringPaths = chainPathsToStringArray(newChainPaths)
      const updatedConfig: ITextTransformConfig = {
        ...transformConfig,
        chainPaths: newStringPaths,
      }
      viewmodel.transformConfig$.next(updatedConfig)
    },
    [viewmodel, transformConfig],
  )

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

  return (
    <div className="box-border size-full flex flex-col gap-4">
      <div className="box-border sticky top-0 z-30 flex flex-col justify-between gap-2 flex-none rounded-lg shadow-sm p-4 bg-gray-50 dark:bg-gray-900">
        <MultiPathInput
          chainPaths={chainPaths}
          onChange={handleChainPathsChange}
          displayMode={displayMode}
          onDisplayModeChange={setDisplayMode}
          placeholder="Add JSON paths for transform nodes (e.g., .data.type)"
        />
      </div>
      <div ref={containerRef} className="box-border flex-auto overflow-auto flex flex-col gap-4">
        {transformedNodes.map((node, index) => (
          <ContentListItem
            key={node.uuid}
            index={index}
            node={node}
            chainPaths={chainPaths}
            expandTick={expandTick}
            isActive={activeRecordIndex === index}
          />
        ))}
      </div>
    </div>
  )
}

ContentList.displayName = 'TextViewContentList'
