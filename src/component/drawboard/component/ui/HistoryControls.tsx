import cn from 'clsx'
import React from 'react'
import { RedoIcon, UndoIcon } from '../icons/MaterialIcons'

interface IHistoryControlsProps {
  canUndo: boolean
  canRedo: boolean
  onUndo: () => void
  onRedo: () => void
  className?: string
}

export const HistoryControls: React.FC<IHistoryControlsProps> = ({
  canUndo,
  canRedo,
  onUndo,
  onRedo,
  className,
}) => {
  return (
    <div
      className={cn(
        'bg-white/90 dark:bg-gray-800/90 backdrop-blur-sm rounded-lg border border-gray-200/60 dark:border-gray-600/60 shadow-sm px-2 py-1 flex items-center gap-1 h-10',
        className,
      )}
    >
      <button
        type="button"
        onClick={onUndo}
        disabled={!canUndo}
        className="p-1.5 hover:bg-gray-100 dark:hover:bg-gray-700 rounded transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
        title="Undo"
      >
        <UndoIcon className="w-4 h-4" />
      </button>

      <button
        type="button"
        onClick={onRedo}
        disabled={!canRedo}
        className="p-1.5 hover:bg-gray-100 dark:hover:bg-gray-700 rounded transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
        title="Redo"
      >
        <RedoIcon className="w-4 h-4" />
      </button>
    </div>
  )
}
