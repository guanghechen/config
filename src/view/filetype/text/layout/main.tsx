import { useStateValue } from '@guanghechen/react-viewmodel'
import cn from 'clsx'
import React from 'react'
import { ContentModeEnum, ModeEnum, useTextViewViewModel } from '../context'
import { ContentPane } from '../pane/content'
import { NavPane } from '../pane/nav'
import { RawPane } from '../pane/raw'
import { TransformPane } from '../pane/transform'

export const Main: React.FC = () => {
  const viewmodel = useTextViewViewModel()
  const contentMode: ContentModeEnum = useStateValue(viewmodel.contentMode$)
  const m = useStateValue(viewmodel.mode$)
  let mode = m < 1 ? 1 : m

  if ((mode & ModeEnum.NAV) === ModeEnum.NAV && contentMode !== ContentModeEnum.LIST) {
    mode = mode ^ ModeEnum.NAV
  }

  return (
    <div
      className={cn('vlm-canvas', `vlm-canvas-${mode}`)}
      data-filetype="text"
      data-content-mode={contentMode}
    >
      {(mode & ModeEnum.CONTENT) !== 0 && (
        <div className="vlm-pane vlm-p-content">
          <ContentPane />
        </div>
      )}
      {(mode & ModeEnum.NAV) !== 0 && contentMode === ContentModeEnum.LIST && (
        <div className="vlm-pane vlm-p-nav">
          <NavPane />
        </div>
      )}
      {(mode & ModeEnum.RAW) !== 0 && (
        <div className="vlm-pane vlm-p-raw">
          <RawPane />
        </div>
      )}
      {(mode & ModeEnum.TRANSFORM) !== 0 && (
        <div className="vlm-pane vlm-p-transform">
          <TransformPane />
        </div>
      )}
    </div>
  )
}
