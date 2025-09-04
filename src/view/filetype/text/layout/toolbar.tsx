import { useStateValue } from '@guanghechen/react-viewmodel'
import React from 'react'
import { createPortal } from 'react-dom'
import type { ITextTransformedNode } from '@/shared/types'
import { CollectionDropdown } from '../container/CollectionDropdown'
import { ContentMode } from '../container/ContentMode'
import { ContentModeEnum, ModeEnum, useTextViewViewModel } from '../context'

export const Toolbar: React.FC = () => {
  const viewmodel = useTextViewViewModel()
  const contentMode: ContentModeEnum = useStateValue(viewmodel.contentMode$)
  const expandTick: number = useStateValue(viewmodel.expandTick$)
  const records: ITextTransformedNode[] = useStateValue(viewmodel.records$)
  const mode = useStateValue(viewmodel.mode$)
  const expanded: boolean = expandTick % 2 === 0

  const [collectionDropdownOpen, setCollectionDropdownOpen] = React.useState(false)
  const portalTarget = React.useMemo(() => document.querySelector('.vlt-middle'), [])

  if (!portalTarget) {
    return null
  }

  const isContentVisible = (mode & ModeEnum.CONTENT) !== 0
  const isTransformInvisible = (mode & ModeEnum.TRANSFORM) === 0
  if (!isContentVisible) {
    return null
  }

  const toolbarContent = (
    <div className="flex items-center justify-center rounded-lg select-none gap-2 px-4 py-2">
      {isTransformInvisible && (
        <CollectionDropdown
          isOpen={collectionDropdownOpen}
          onClose={() => setCollectionDropdownOpen(false)}
          onToggle={() => setCollectionDropdownOpen(!collectionDropdownOpen)}
        />
      )}
      <ContentMode />
      <div className="flex items-center">
        <span className="text-sm font-medium text-gray-800 dark:text-gray-200">
          Records ({records.length ?? 0})
        </span>
      </div>
      {contentMode === ContentModeEnum.LIST && records && (
        <button
          className="select-none cursor-pointer text-sm font-medium text-blue-600 transition-colors duration-200 hover:text-blue-700 hover:underline focus:outline-none focus:ring-2 focus:ring-blue-500/50 focus:ring-offset-2 active:text-blue-800 dark:text-blue-400 dark:hover:text-blue-300 dark:active:text-blue-200"
          onClick={() => viewmodel.expandTick$.setState(tick => tick + 1)}
          title={expanded ? 'Collapse All' : 'Expand All'}
        >
          {expanded ? 'Collapse All' : 'Expand All'}
        </button>
      )}
    </div>
  )

  return createPortal(toolbarContent, portalTarget)
}
Toolbar.displayName = 'TextViewToolbar'
