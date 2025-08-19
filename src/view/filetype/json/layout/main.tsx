import { useStateValue } from '@guanghechen/react-viewmodel'
import cn from 'clsx'
import React from 'react'
import { ModeEnum, useJsonViewViewModel } from '../context'
import { ContentPane } from './content'
import { LiteralPane } from './literal'

export const Main: React.FC = () => {
  const viewmodel = useJsonViewViewModel()
  const mode = useStateValue(viewmodel.mode$)

  return (
    <div className={cn('f-vf-main', `f-vf-main-${mode}`)} data-filetype="json">
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

Main.displayName = 'JsonViewMain'
