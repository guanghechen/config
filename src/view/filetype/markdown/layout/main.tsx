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
  const mode = useStateValue(viewmodel.mode$)

  return (
    <div className={cn('f-vf-main', `f-vf-main-${mode}`)} data-filetype="markdown">
      {(mode & ModeEnum.CONTENT) !== 0 && (
        <div className="f-vf-pane f-vfp-content">
          <ContentPane />
        </div>
      )}
      {(mode & ModeEnum.AST) !== 0 && (
        <div className="f-vf-pane f-vfp-ast">
          <AstPane />
        </div>
      )}
      {(mode & ModeEnum.TOC) !== 0 && (
        <div className="f-vf-pane f-vfp-toc">
          <TocPane />
        </div>
      )}
      {(mode & ModeEnum.FM) !== 0 && (
        <div className="f-vf-pane f-vfp-fm">
          <FrontmatterPane />
        </div>
      )}
    </div>
  )
}

Main.displayName = 'MarkdownViewMain'
