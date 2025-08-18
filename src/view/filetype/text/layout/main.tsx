import { useStateValue } from '@guanghechen/react-viewmodel'
import cn from 'clsx'
import React from 'react'
import { ModeEnum, useTextViewViewModel } from '../context'
import { ContentPane } from '../pane/content'
import { NavPane } from '../pane/nav'
import { RawPane } from '../pane/raw'
import { TransformPane } from '../pane/transform'

export const Main: React.FC = () => {
  const viewmodel = useTextViewViewModel()
  const mode = useStateValue(viewmodel.mode$)

  return (
    <div className={cn('f-vf-main', `f-vf-main-${mode}`)}>
      {(mode & ModeEnum.CONTENT) !== 0 && (
        <div className="f-vf-pane f-vfp-content">
          <ContentPane />
        </div>
      )}
      {(mode & ModeEnum.NAV) !== 0 && (
        <div className="f-vf-pane f-vfp-nav">
          <NavPane />
        </div>
      )}
      {(mode & ModeEnum.RAW) !== 0 && (
        <div className="f-vf-pane f-vfp-raw">
          <RawPane />
        </div>
      )}
      {(mode & ModeEnum.TRANSFORM) !== 0 && (
        <div className="f-vf-pane f-vfp-transform">
          <TransformPane />
        </div>
      )}
    </div>
  )
}
