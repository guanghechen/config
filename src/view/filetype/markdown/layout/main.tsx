import { useStateValue } from '@guanghechen/react-viewmodel'
import cn from 'clsx'
import React from 'react'
import { ModeEnum, useMarkdownViewViewModel } from '../context'
import { AstPane } from '../pane/ast'
import { ContentPane } from '../pane/content'
import { FrontmatterPane } from '../pane/frontmatter'
import { TocPane } from '../pane/toc'

export const Main: React.FC = () => {
  const viewmodel = useMarkdownViewViewModel()
  const m = useStateValue(viewmodel.mode$)
  const mode = m < 1 ? 1 : m

  return (
    <div className={cn('vlm-canvas', `vlm-canvas-${mode}`)} data-filetype="markdown">
      {(mode & ModeEnum.CONTENT) !== 0 && (
        <div className="vlm-pane vlm-p-content">
          <ContentPane />
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
