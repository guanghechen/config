import { useEventCallback } from '@guanghechen/react-hooks'
import { useStateValue } from '@guanghechen/react-viewmodel'
import type { Root } from '@yozora/ast'
import type { IHeadingToc, IHeadingTocNode } from '@yozora/ast-util'
import cn from 'clsx'
import throttle from 'lodash.throttle'
import React from 'react'
import { useMarkdownAst } from '@/component/markdown'
import { ModeEnum, useMarkdownViewViewModel } from '../context'
import { AstView } from '../pane/ast'
import { FrontmatterView } from '../pane/frontmatter'
import { MdView } from '../pane/md'
import { TocView } from '../pane/toc'

export const Main: React.FC = () => {
  const viewmodel = useMarkdownViewViewModel()
  const data = useStateValue(viewmodel.data$)
  const mode = useStateValue(viewmodel.mode$)
  const tocActivatedIdentifier = useStateValue(viewmodel.tocActivatedIdentifier$)
  const specifiedTocActivatedIdentifier = useStateValue(viewmodel.specifiedTocActivatedIdentifier$)

  const ast: Root = useMarkdownAst()
  const toc: IHeadingToc | undefined = data?.toc
  const frontmatter: Record<string, unknown> | undefined = data?.frontmatter
  const filepath: string | null = useStateValue(viewmodel.filepath$)

  const contentContainerRef = React.useRef<HTMLDivElement | null>(null)
  const specifiedTocIdentifierTimerRef = React.useRef<ReturnType<typeof setTimeout> | null>(null)
  const specifiedTocActivatedIdentifierRef = React.useRef<string | null>(
    specifiedTocActivatedIdentifier,
  )

  // Keep the ref in sync with the state
  React.useEffect(() => {
    specifiedTocActivatedIdentifierRef.current = specifiedTocActivatedIdentifier
  }, [specifiedTocActivatedIdentifier])

  const showView: boolean = mode === 0 || (mode & ModeEnum.VIEW) !== 0
  const showAst: boolean = (mode & ModeEnum.AST) !== 0
  const showToc: boolean = (mode & ModeEnum.TOC) !== 0
  const showFm: boolean = (mode & ModeEnum.FM) !== 0
  const columns: number = (showView ? 1 : 0) + (showAst ? 1 : 0) + (showToc || showFm ? 1 : 0)

  const setTimeoutForSpecifiedTocIdentifier = useEventCallback((): void => {
    specifiedTocIdentifierTimerRef.current = setTimeout(() => {
      specifiedTocIdentifierTimerRef.current = null
      const specifiedTocIdentifier: string | null = specifiedTocActivatedIdentifierRef.current
      if (specifiedTocIdentifier !== null) {
        viewmodel.specifiedTocActivatedIdentifier$.next(null)
        viewmodel.tocActivatedIdentifier$.next(specifiedTocIdentifier)
      }
    }, 72)
  })

  const setActivatedIdentifier = React.useCallback(
    (activatedIdentifier: string | null) => {
      viewmodel.specifiedTocActivatedIdentifier$.next(activatedIdentifier)
      setTimeoutForSpecifiedTocIdentifier()
    },
    [setTimeoutForSpecifiedTocIdentifier, viewmodel.specifiedTocActivatedIdentifier$],
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
      viewmodel.tocActivatedIdentifier$.next(nextTocActivatedIdentifier)

      if (specifiedTocIdentifierTimerRef.current) {
        clearTimeout(specifiedTocIdentifierTimerRef.current)
        setTimeoutForSpecifiedTocIdentifier()
      }
    }, 50)

    onScroll()
    contentContainer.addEventListener('scroll', onScroll)
    return () => contentContainer.removeEventListener('scroll', onScroll)
  }, [
    contentContainer,
    setTimeoutForSpecifiedTocIdentifier,
    showToc,
    toc,
    viewmodel.tocActivatedIdentifier$,
  ])

  return (
    <div className="size-full flex justify-center">
      {showView && (
        <React.Fragment>
          <MdView
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
  )
}

Main.displayName = 'MarkdownViewMain'
