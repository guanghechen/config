import { useStateValue } from '@guanghechen/react-viewmodel'
import React from 'react'
import { useDrawboardContext } from '../../context'
import { ToolMode } from '../../context/types'

interface IToolHint {
  mode: ToolMode
  hint: string
  shortTip?: string
}

const TOOL_HINTS: IToolHint[] = [
  {
    mode: ToolMode.SELECT,
    hint: 'Click and drag to select elements',
    shortTip: 'Select',
  },
  {
    mode: ToolMode.LASSO,
    hint: 'Draw a lasso around elements to select them',
    shortTip: 'Lasso',
  },
  {
    mode: ToolMode.PAN,
    hint: 'Click and drag to pan the canvas',
    shortTip: 'Pan',
  },
  {
    mode: ToolMode.RECTANGLE,
    hint: 'Click and drag to draw a rectangle',
    shortTip: 'Rectangle',
  },
  {
    mode: ToolMode.DIAMOND,
    hint: 'Click and drag to draw a diamond',
    shortTip: 'Diamond',
  },
  {
    mode: ToolMode.CIRCLE,
    hint: 'Click and drag to draw an ellipse',
    shortTip: 'Ellipse',
  },
  {
    mode: ToolMode.ARROW,
    hint: 'Click and drag to draw an arrow',
    shortTip: 'Arrow',
  },
  {
    mode: ToolMode.LINE,
    hint: 'Click and drag to draw a line',
    shortTip: 'Line',
  },
  {
    mode: ToolMode.FREEDRAW,
    hint: 'Click and drag to draw freehand',
    shortTip: 'Draw',
  },
  {
    mode: ToolMode.TEXT,
    hint: 'Click to add text',
    shortTip: 'Text',
  },
  {
    mode: ToolMode.IMAGE,
    hint: 'Click to insert an image',
    shortTip: 'Image',
  },
  {
    mode: ToolMode.ERASER,
    hint: 'Click on elements to erase them',
    shortTip: 'Eraser',
  },
  {
    mode: ToolMode.FRAME,
    hint: 'Click and drag to create a frame',
    shortTip: 'Frame',
  },
  {
    mode: ToolMode.LASER,
    hint: 'Click and drag to use laser pointer',
    shortTip: 'Laser',
  },
]

interface IHintViewerProps {
  variant?: 'full' | 'compact'
  className?: string
}

export const HintViewer: React.FC<IHintViewerProps> = ({ variant = 'full', className = '' }) => {
  const { ui } = useDrawboardContext()
  const selectedTool = useStateValue(ui.selectedTool$)

  const currentHint = TOOL_HINTS.find(hint => hint.mode === selectedTool)

  if (!currentHint) return null

  if (variant === 'compact') {
    return (
      <div className={`text-xs text-gray-500 dark:text-gray-400 ${className}`}>
        {currentHint.shortTip}
      </div>
    )
  }

  return (
    <div
      className={`bg-white/90 dark:bg-gray-800/90 backdrop-blur-sm rounded-lg px-3 py-2 text-sm text-gray-600 dark:text-gray-300 shadow-sm dark:shadow-black/20 border border-gray-200/50 dark:border-gray-600/50 ${className}`}
    >
      <div className="flex items-center gap-2">
        <div className="h-2 w-2 rounded-full bg-blue-500 dark:bg-blue-400" />
        <span>{currentHint.hint}</span>
      </div>
    </div>
  )
}
