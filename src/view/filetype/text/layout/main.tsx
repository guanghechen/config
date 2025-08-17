import { useStateValue } from '@guanghechen/react-viewmodel'
import React from 'react'
import type { IPrismThemeScheme } from '@/component/code-highlighter'
import { vscDarkTheme, vscLightTheme } from '@/component/code-highlighter'
import { SiteTheme, useSiteViewmodel } from '@/context/site'
import type { ITextTransformedNode } from '@/shared/types'
import { ModeEnum, useTextViewViewModel } from '../context'
import type { ViewModeEnum } from '../context/types'
import { RawPane } from '../pane/raw'
import { TransformPane } from '../pane/transform'
import { ViewPane } from '../pane/view'

export const Main: React.FC = () => {
  const siteVM = useSiteViewmodel()
  const theme: SiteTheme = useStateValue(siteVM.theme$)
  const themeScheme: IPrismThemeScheme = theme === SiteTheme.DARKEN ? vscDarkTheme : vscLightTheme

  const viewmodel = useTextViewViewModel()
  const mode = useStateValue(viewmodel.mode$)
  const viewMode: ViewModeEnum = useStateValue(viewmodel.viewMode$)
  const content: string | null = useStateValue(viewmodel.content$)
  const transformedNodes: ITextTransformedNode[] | null = useStateValue(viewmodel.transformedNodes$)

  const showView: boolean = (mode & ModeEnum.VIEW) !== 0
  const showRaw: boolean = (mode & ModeEnum.RAW) !== 0
  const showTransform: boolean = (mode & ModeEnum.TRANSFORM) !== 0
  const columns: number = (showView ? 1 : 0) + (showRaw ? 1 : 0) + (showTransform ? 1 : 0)

  if (!content) {
    return (
      <div className="size-full flex justify-center">
        <div className="text-gray-500 dark:text-gray-400">Loading...</div>
      </div>
    )
  }

  return (
    <div className="size-full flex justify-center">
      {showView && (
        <React.Fragment>
          <ViewPane
            content={content}
            viewMode={viewMode}
            transformedNodes={transformedNodes}
            columns={columns}
          />
          {columns > 1 && (
            <div className="mx-2 h-full flex-shrink-0 border-r border-gray-300 dark:border-gray-700" />
          )}
        </React.Fragment>
      )}
      {showRaw && (
        <React.Fragment>
          {columns > 1 && (
            <div className="mx-2 h-full flex-shrink-0 border-r border-gray-300 dark:border-gray-700" />
          )}
          <RawPane content={content} themeScheme={themeScheme} columns={columns} />
        </React.Fragment>
      )}
      {showTransform && (
        <React.Fragment>
          {columns > 1 && (
            <div className="mx-2 h-full flex-shrink-0 border-r border-gray-300 dark:border-gray-700" />
          )}
          <TransformPane columns={columns} />
        </React.Fragment>
      )}
    </div>
  )
}

Main.displayName = 'TextMain'
