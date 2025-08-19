import { useStateValue } from '@guanghechen/react-viewmodel'
import cn from 'clsx'
import React from 'react'
import { ModeEnum, useHtmlViewViewModel } from '../context'
import { ContentPane } from '../pane/content'
import { LiteralPane } from '../pane/literal'

interface IProps {
  readonly workspace: string | null
}

export const Main: React.FC<IProps> = props => {
  const { workspace } = props
  const viewmodel = useHtmlViewViewModel()
  const mode = useStateValue(viewmodel.mode$)

  return (
    <div className={cn('f-vf-main', `f-vf-main-${mode}`)} data-filetype="html">
      {(mode & ModeEnum.CONTENT) !== 0 && (
        <div className="f-vf-pane f-vfp-content">
          <ContentPane workspace={workspace} />
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

Main.displayName = 'HtmlViewMain'
