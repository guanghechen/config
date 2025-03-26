import { useStateValue } from '@guanghechen/react-viewmodel'
import type { Root } from '@yozora/ast'
import type { IHeadingToc } from '@yozora/ast-util'
import cn from 'clsx'
import React from 'react'
import { Json } from '@/component/json'
import { MarkdownProvider, MarkdownToc, ReactMarkdown } from '@/component/markdown'
import { ReactMarkdownContent } from '@/component/markdown/ReactMarkdownContent'
import { PRESET_CLASSES } from '@/constant/classes'
import type { SiteTheme } from '@/context/site'
import { useSiteViewmodel } from '@/context/site'
import { MarkdownModeEnum, useWorkspaceViewmodel } from '../../context'

interface IProps {
  readonly filepath: string | null
  readonly ast: Root
  readonly toc: IHeadingToc | undefined
  readonly frontmatter: Record<string, unknown> | undefined
}

export const MarkdownComposer: React.FC<IProps> = props => {
  const { ast, toc, frontmatter, filepath } = props
  const siteVM = useSiteViewmodel()
  const workspaceVM = useWorkspaceViewmodel()
  const mode: MarkdownModeEnum = useStateValue(workspaceVM.markdownMode$)
  const theme: SiteTheme = useStateValue(siteVM.theme$)

  const showView: boolean = mode === 0 || (mode & MarkdownModeEnum.VIEW) !== 0
  const showAst: boolean = (mode & MarkdownModeEnum.AST) !== 0
  const showToc: boolean = (mode & MarkdownModeEnum.TOC) !== 0
  const showFm: boolean = (mode & MarkdownModeEnum.FM) !== 0
  const columns: number = (showView ? 1 : 0) + (showAst ? 1 : 0) + (showToc || showFm ? 1 : 0)

  return (
    <MarkdownProvider ast={ast} theme={theme}>
      <div className="flex h-[calc(100vh-5rem)] w-full items-start justify-center p-4">
        {showView && (
          <React.Fragment>
            <div
              className={cn('h-full w-[72rem] flex-initial', PRESET_CLASSES.scrollbar, {
                'p-2 overflow-auto': columns > 1,
              })}
            >
              <ReactMarkdownContent
                Tag="h1"
                className="mb-4 flex justify-center text-3xl font-bold text-gray-900 dark:text-white"
                content={(frontmatter?.title as string) || filepath || 'Untitled'}
              />
              <ReactMarkdown className="pb-4" />
            </div>
            {columns > 1 && <div className="mx-2 h-full flex-shrink-0 border-r border-gray-300" />}
          </React.Fragment>
        )}
        {showAst && (
          <React.Fragment>
            <div
              className={cn('h-full w-[48rem] flex-initial', PRESET_CLASSES.scrollbar, {
                'p-2 overflow-auto': columns > 1,
              })}
            >
              <Json json={ast} />
            </div>
            {(showToc || showFm) && (
              <div className="mx-2 h-full flex-shrink-0 border-r border-gray-300" />
            )}
          </React.Fragment>
        )}
        {(showToc || showFm) && (
          <div
            className={cn('flex h-full justify-center', {
              'w-[32rem] flex-col flex-initial': columns > 1,
            })}
          >
            <div
              className={cn('flex-auto basis-0 overflow-auto p-2', PRESET_CLASSES.scrollbar, {
                'flex justify-center': columns === 1,
                hidden: !showToc,
              })}
            >
              <h3 className="mb-4 text-lg font-medium text-gray-800 dark:text-gray-100">
                Table of Contents
              </h3>
              <div>
                <MarkdownToc toc={toc} />
              </div>
            </div>
            <div
              className={cn('flex-shrink-0 border-gray-300', {
                'mx-2 h-full border-r': columns === 1,
                'my-2 w-full border-b': columns > 1,
                hidden: !showToc || !showFm,
              })}
            />
            <div
              className={cn('flex-auto basis-0 overflow-auto p-2', PRESET_CLASSES.scrollbar, {
                'flex justify-center': columns === 1,
                hidden: !showFm,
              })}
            >
              <h3 className="mb-4 text-lg font-medium text-gray-800 dark:text-gray-100">
                Frontmatter
              </h3>
              <Json json={frontmatter} initialCollapsed="expanded" />
            </div>
          </div>
        )}
      </div>
    </MarkdownProvider>
  )
}

MarkdownComposer.displayName = 'MarkdownComposer'
