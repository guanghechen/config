import { useStateValue } from '@guanghechen/react-viewmodel'
import cn from 'clsx'
import React from 'react'
import { ModeEnum, ViewModeEnum, useTextViewViewModel } from '../context'
import { ContentPane } from '../pane/content'
import { NavPane } from '../pane/nav'
import { RawPane } from '../pane/raw'
import { TransformPane } from '../pane/transform'

export const Main: React.FC = () => {
  const viewmodel = useTextViewViewModel()
  const viewMode: ViewModeEnum = useStateValue(viewmodel.viewMode$)
  let mode = useStateValue(viewmodel.mode$)

  if ((mode & ModeEnum.NAV) !== 1 && viewMode !== ViewModeEnum.LIST) {
    mode = mode ^ ModeEnum.NAV
  }

  return (
    <div className={cn('f-vf-main', `f-vf-main-${mode}`)} data-filetype="text">
      {(mode & ModeEnum.CONTENT) !== 0 && (
        <div className="f-vf-pane f-vfp-content">
          <ContentPane />
        </div>
      )}
      {(mode & ModeEnum.NAV) !== 0 && viewMode === ViewModeEnum.LIST && (
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
