import { useEventCallback } from '@guanghechen/react-hooks'
import { useStateValue } from '@guanghechen/react-viewmodel'
import type { Root } from '@yozora/ast'
import type { IHeadingToc, IHeadingTocNode } from '@yozora/ast-util'
import cn from 'clsx'
import throttle from 'lodash.throttle'
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
  const { markdownMode$, tocActivatedIdentifier$, specifiedTocActivatedIdentifier$ } =
    useWorkspaceViewmodel()

  const mode: MarkdownModeEnum = useStateValue(markdownMode$)
  const theme: SiteTheme = useStateValue(siteVM.theme$)
  const tocActivatedIdentifier: string | null = useStateValue(tocActivatedIdentifier$)

  const contentContainerRef = React.useRef<HTMLDivElement | null>(null)
  const specifiedTocIdentifierTimerRef = React.useRef<ReturnType<typeof setTimeout> | null>(null)

  const showView: boolean = mode === 0 || (mode & MarkdownModeEnum.VIEW) !== 0
  const showAst: boolean = (mode & MarkdownModeEnum.AST) !== 0
  const showToc: boolean = (mode & MarkdownModeEnum.TOC) !== 0
  const showFm: boolean = (mode & MarkdownModeEnum.FM) !== 0
  const columns: number = (showView ? 1 : 0) + (showAst ? 1 : 0) + (showToc || showFm ? 1 : 0)

  const setTimeoutForSpecifiedTocIdentifier = useEventCallback((): void => {
    specifiedTocIdentifierTimerRef.current = setTimeout(() => {
      specifiedTocIdentifierTimerRef.current = null
      const specifiedTocIdentifier: string | null = specifiedTocActivatedIdentifier$.getSnapshot()
      if (specifiedTocIdentifier !== null) {
        specifiedTocActivatedIdentifier$.next(null)
        tocActivatedIdentifier$.next(specifiedTocIdentifier)
      }
    }, 72)
  })

  const setActivatedIdentifier = React.useCallback(
    (activatedIdentifier: string | null) => {
      specifiedTocActivatedIdentifier$.next(activatedIdentifier)
      setTimeoutForSpecifiedTocIdentifier()
    },
    [setTimeoutForSpecifiedTocIdentifier, specifiedTocActivatedIdentifier$],
  )

  const contentContainer: HTMLDivElement | null = contentContainerRef.current
  React.useEffect(() => {
    if (!showToc || !toc || !contentContainer) return

    const identifiers: Array<[string, HTMLElement]> = []
    const collect = (item: IHeadingTocNode): void => {
      let identifier: string = decodeURIComponent(item.identifier)
      identifier = encodeURIComponent(item.identifier)
      const element: HTMLElement | null = document.getElementById(identifier)
      if (element) identifiers.push([item.identifier, element])
      for (const child of item.children) collect(child)
    }
    for (const child of toc.children) collect(child)

    const onScroll = throttle((): void => {
      const viewportTopOffset: number = 48
      let nextTocActivatedIdentifier: string | null = null
      for (const [identifier, element] of identifiers) {
        if (element.getBoundingClientRect().top >= viewportTopOffset) {
          nextTocActivatedIdentifier = identifier
          break
        }
      }
      tocActivatedIdentifier$.next(nextTocActivatedIdentifier)

      if (specifiedTocIdentifierTimerRef.current) {
        clearTimeout(specifiedTocIdentifierTimerRef.current)
        setTimeoutForSpecifiedTocIdentifier()
      }
    }, 50)

    onScroll()
    contentContainer.addEventListener('scroll', onScroll)
    return () => contentContainer.removeEventListener('scroll', onScroll)
  }, [toc, showToc, contentContainer, tocActivatedIdentifier$, setTimeoutForSpecifiedTocIdentifier])

  return (
    <MarkdownProvider ast={ast} theme={theme}>
      <div
        className={cn('flex w-full items-start justify-center', {
          'h-[calc(100vh-7rem)]': columns > 1,
        })}
      >
        {showView && (
          <React.Fragment>
            <ContentView
              containerRef={contentContainerRef}
              ast={ast}
              filepath={filepath}
              frontmatter={frontmatter}
              singleColumn={columns === 1}
            />
            {columns > 1 && (
              <div className="mx-2 h-full flex-shrink-0 border-r border-gray-300 dark:border-gray-700" />
            )}
          </React.Fragment>
        )}
        {showAst && (
          <React.Fragment>
            <AstView ast={ast} singleColumn={columns === 1} />
            {(showToc || showFm) && (
              <div className="mx-2 h-full flex-shrink-0 border-r border-gray-300 dark:border-gray-700" />
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
                setActivatedIdentifier={setActivatedIdentifier}
              />
            )}
            <div
              className={cn('flex-shrink-0 border-gray-300 dark:border-gray-700', {
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
