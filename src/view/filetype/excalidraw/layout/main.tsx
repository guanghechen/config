import { useStateValue } from '@guanghechen/react-viewmodel'
import cn from 'clsx'
import React from 'react'
import { ModeEnum, useExcalidrawViewViewModel } from '../context'
import { ContentPane } from '../pane/content'

export const Main: React.FC = () => {
  const viewmodel = useExcalidrawViewViewModel()
  const mode: ModeEnum = useStateValue(viewmodel.mode$)

  return (
    <div className={cn('f-vf-main', `f-vf-main-${mode}`)} data-filetype="excalidraw">
      {(mode & ModeEnum.CONTENT) !== 0 && (
        <div className="f-vf-pane f-vfp-content">
          <ContentPane />
        </div>
      )}
    </div>
  )
}

Main.displayName = 'MarkdownViewMain'
