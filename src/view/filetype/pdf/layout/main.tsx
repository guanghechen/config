import { useStateValue } from '@guanghechen/react-viewmodel'
import cn from 'clsx'
import React from 'react'
import { ModeEnum, usePdfViewViewModel } from '../context'
import { ContentPane } from '../pane/content'

export const Main: React.FC = () => {
  const viewmodel = usePdfViewViewModel()
  const mode = useStateValue(viewmodel.mode$)

  return (
    <div className={cn('f-vf-main', `f-vf-main-${mode}`)} data-filetype="pdf">
      {(mode & ModeEnum.CONTENT) !== 0 && (
        <div className="f-vf-pane f-vfp-content">
          <ContentPane />
        </div>
      )}
    </div>
  )
}

Main.displayName = 'PdfViewMain'
