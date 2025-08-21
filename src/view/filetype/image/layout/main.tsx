import { useStateValue } from '@guanghechen/react-viewmodel'
import cn from 'clsx'
import React from 'react'
import { ModeEnum, useImageViewViewModel } from '../context'
import { ContentPane } from '../pane/content'
import { LiteralPane } from '../pane/literal'

export const Main: React.FC = () => {
  const viewmodel = useImageViewViewModel()
  const m = useStateValue(viewmodel.mode$)
  const mode = m < 1 ? 1 : m

  return (
    <div className={cn('f-vf-main', `f-vf-main-${mode}`)} data-filetype="image">
      {(mode & ModeEnum.CONTENT) !== 0 && (
        <div className="f-vf-pane f-vfp-content">
          <ContentPane />
        </div>
      )}
      {(mode & ModeEnum.LITERAL) !== 0 && (
        <div className="f-vf-pane f-vfp-literal">
          <LiteralPane />
        </div>
      )}
    </div>
  )
}
Main.displayName = 'ImageViewMain'
