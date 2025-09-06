import { useStateValue } from '@guanghechen/react-viewmodel'
import cn from 'clsx'
import React from 'react'
import { ModeEnum, useDrawboardViewViewModel } from '../context'
import { CanvasPane } from '../pane/canvas'
import { SourcePane } from '../pane/source'

export const Main: React.FC = () => {
  const viewmodel = useDrawboardViewViewModel()
  const m: ModeEnum = useStateValue(viewmodel.mode$)
  const mode = m < 1 ? 1 : m

  return (
    <div className={cn('vlm-canvas', `vlm-canvas-${mode}`)} data-filetype="drawboard">
      {(mode & ModeEnum.SOURCE) !== 0 && (
        <div className="vlm-pane vlm-p-source">
          <SourcePane />
        </div>
      )}
      {(mode & ModeEnum.CANVAS) !== 0 && (
        <div className="vlm-pane vlm-p-canvas">
          <CanvasPane />
        </div>
      )}
    </div>
  )
}

Main.displayName = 'DrawboardViewMain'
