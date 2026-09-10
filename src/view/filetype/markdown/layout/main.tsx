import { useStateValue } from '@guanghechen/react-viewmodel'
import cn from '@/common/util/clsx'
import React from 'react'
import { ModeEnum, useMarkdownViewViewModel } from '../context'
import { AstPane } from '../pane/ast'
import { ContentPane } from '../pane/content'
import { FrontmatterPane } from '../pane/frontmatter'
import { TocPane } from '../pane/toc'
import { FullscreenToggle } from './fullscreen'
import { ScrollToTop } from './scroll-to-top'

export const Main: React.FC = () => {
  const viewmodel = useMarkdownViewViewModel()
  const m = useStateValue(viewmodel.mode$)
  const mode = m < 1 ? 1 : m

  return (
    <div className={cn('vlm-canvas', `vlm-canvas-${mode}`)} data-filetype="markdown">
      {(mode & ModeEnum.CONTENT) !== 0 && (
        <div className="vlm-pane vlm-p-content">
          <div className="vlm-content-actions">
            <FullscreenToggle />
          </div>
          <div className="flex w-full justify-center pt-8">
            <ContentPane />
          </div>
          <div className="vlm-content-scroll-actions">
            <ScrollToTop />
          </div>
        </div>
      )}
      {(mode & ModeEnum.AST) !== 0 && (
        <div className="vlm-pane vlm-p-ast">
          <AstPane />
        </div>
      )}
      {(mode & ModeEnum.TOC) !== 0 && (
        <div className="vlm-pane vlm-p-toc">
          <TocPane />
        </div>
      )}
      {(mode & ModeEnum.FM) !== 0 && (
        <div className="vlm-pane vlm-p-fm">
          <FrontmatterPane />
        </div>
      )}
    </div>
  )
}

Main.displayName = 'MarkdownViewMain'
