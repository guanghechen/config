import { useStateValue } from '@guanghechen/react-viewmodel'
import cn from 'clsx'
import React from 'react'
import type { IPrismThemeScheme } from '@/component/code-highlighter'
import { vscDarkTheme, vscLightTheme } from '@/component/code-highlighter'
import { SiteTheme, useSiteViewmodel } from '@/context/site'
import type { ITextTransformedNode } from '@/shared/types'
import { ModeEnum, useTextViewViewModel } from '../context'
import type { ViewModeEnum } from '../context/types'
import { NavPane } from '../pane/nav'
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
  const activeRecordIndex: number | null = useStateValue(viewmodel.activeRecordIndex$)

  const showView: boolean = (mode & ModeEnum.VIEW) !== 0
  const showNav: boolean = (mode & ModeEnum.NAV) !== 0
  const showRaw: boolean = (mode & ModeEnum.RAW) !== 0
  const showTransform: boolean = (mode & ModeEnum.TRANSFORM) !== 0
  const columns: number =
    (showView ? 1 : 0) + (showNav ? 1 : 0) + (showRaw ? 1 : 0) + (showTransform ? 1 : 0)

  const handleRecordClick = React.useCallback(
    (index: number) => {
      viewmodel.activeRecordIndex$.next(index)
    },
    [viewmodel],
  )

  if (!content) {
    return (
      <div className="size-full flex justify-center">
        <div className="text-gray-500 dark:text-gray-400">Loading...</div>
      </div>
    )
  }

  return (
    <div
      className={cn('box-border p-0 m-0', {
        'f-view-text__single-column': columns === 1,
        'f-view-text__view-raw': showView && showRaw && !showTransform && !showNav,
        'f-view-text__view-transform': showView && !showRaw && showTransform && !showNav,
        'f-view-text__view-nav': showView && showNav && !showRaw && !showTransform,
        'f-view-text__raw-transform': !showView && showRaw && showTransform && !showNav,
        'f-view-text__view-raw-transform': showView && showRaw && showTransform && !showNav,
        'f-view-text__multiple-panes': columns > 1,
      })}
    >
      {showView && (
        <div className="f-view-text__pane f-view-text__pane--view">
          <ViewPane
            content={content}
            viewMode={viewMode}
            transformedNodes={transformedNodes}
            columns={columns}
          />
        </div>
      )}
      {showNav && transformedNodes && (
        <div className="f-view-text__pane f-view-text__pane--nav">
          <NavPane
            records={transformedNodes}
            singleColumn={columns === 1}
            onRecordClick={handleRecordClick}
            activeRecordIndex={activeRecordIndex}
          />
        </div>
      )}
      {showRaw && (
        <div className="f-view-text__pane f-view-text__pane--raw">
          <RawPane content={content} themeScheme={themeScheme} columns={columns} />
        </div>
      )}
      {showTransform && (
        <div className="f-view-text__pane f-view-text__pane--transform">
          <TransformPane columns={columns} />
        </div>
      )}
    </div>
  )
}

Main.displayName = 'TextMain'
