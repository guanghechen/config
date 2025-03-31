import { useStateValue } from '@guanghechen/react-viewmodel'
import type { Root } from '@yozora/ast'
import type { IHeadingToc } from '@yozora/ast-util'
import cn from 'clsx'
import React from 'react'
import { MarkdownProvider } from '@/component/markdown'
import type { SiteTheme } from '@/context/site'
import { useSiteViewmodel } from '@/context/site'
import { MarkdownModeEnum, useWorkspaceViewmodel } from '@/context/workspace'
import { AstView, ContentView, FrontmatterView, TocView } from './view'

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
  const tocActivatedIdentifier: string | null = useStateValue(workspaceVM.tocActivatedIdentifier$)

  const showView: boolean = mode === 0 || (mode & MarkdownModeEnum.VIEW) !== 0
  const showAst: boolean = (mode & MarkdownModeEnum.AST) !== 0
  const showToc: boolean = (mode & MarkdownModeEnum.TOC) !== 0
  const showFm: boolean = (mode & MarkdownModeEnum.FM) !== 0
  const columns: number = (showView ? 1 : 0) + (showAst ? 1 : 0) + (showToc || showFm ? 1 : 0)

  return (
    <MarkdownProvider ast={ast} theme={theme}>
      <div
        className={cn('flex w-full items-start justify-center pb-8', {
          'h-[calc(100vh-6rem)]': columns > 1,
        })}
      >
        {showView && (
          <React.Fragment>
            <ContentView
              filepath={filepath}
              frontmatter={frontmatter}
              singleColumn={columns === 1}
            />
            {columns > 1 && <div className="mx-2 h-full flex-shrink-0 border-r border-gray-300" />}
          </React.Fragment>
        )}
        {showAst && (
          <React.Fragment>
            <AstView ast={ast} singleColumn={columns === 1} />
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
            {showToc && (
              <TocView
                singleColumn={columns === 1}
                toc={toc}
                tocActivatedIdentifier={tocActivatedIdentifier}
              />
            )}
            <div
              className={cn('flex-shrink-0 border-gray-300', {
                'mx-2 h-full border-r': columns === 1,
                'my-2 w-full border-b': columns > 1,
                hidden: !showToc || !showFm,
              })}
            />
            {showFm && <FrontmatterView frontmatter={frontmatter} singleColumn={columns === 1} />}
          </div>
        )}
      </div>
    </MarkdownProvider>
  )
}

MarkdownComposer.displayName = 'MarkdownComposer'
