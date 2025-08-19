import { useStateValue } from '@guanghechen/react-viewmodel'
import cn from 'clsx'
import React from 'react'
import { ModeEnum, useExcalidrawViewViewModel } from '../context'
import { ContentPane } from '../pane/content'

interface IProps {
  readonly filepath: string
  readonly workspace: string | null
}

export const Main: React.FC<IProps> = props => {
  const { filepath, workspace } = props
  const viewmodel = useExcalidrawViewViewModel()
  const mode = useStateValue(viewmodel.mode$)

  return (
    <div className={cn('f-vf-main', `f-vf-main-${mode}`)} data-filetype="markdown">
      {(mode & ModeEnum.CONTENT) !== 0 && (
        <div className="f-vf-pane f-vfp-content">
          <ContentPane filepath={filepath} workspace={workspace} />
        </div>
      )}
    </div>
  )
}

Main.displayName = 'MarkdownViewMain'
