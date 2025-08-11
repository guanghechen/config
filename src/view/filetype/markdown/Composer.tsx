import { useEventCallback } from '@guanghechen/react-hooks'
import { useStateValue } from '@guanghechen/react-viewmodel'
import type { Root } from '@yozora/ast'
import type { IHeadingToc, IHeadingTocNode } from '@yozora/ast-util'
import cn from 'clsx'
import throttle from 'lodash.throttle'
import React from 'react'
import { useMarkdownAst } from '@/component/markdown'
import { useScrollToTop } from '@/hook/useScrollToTop'
import { AstView } from './container/AstView'
import { ContentView } from './container/ContentView'
import { FrontmatterView } from './container/FrontmatterView'
import { ModeToggle } from './container/ModeToggle'
import { TocView } from './container/TocView'
import { ModeEnum, useMarkdownViewViewModel } from './context'

interface IProps {
  readonly filepath: string | null
  readonly frontmatter: Record<string, unknown> | undefined
  readonly toc: IHeadingToc | undefined
  readonly mainScrollableContainer: HTMLDivElement | null
  readonly topbarVisible: boolean
}

export const Composer: React.FC<IProps> = props => {
  const { toc, frontmatter, filepath, mainScrollableContainer, topbarVisible } = props
  const viewmodel = useMarkdownViewViewModel()
  const mode = useStateValue(viewmodel.mode$)
  const tocActivatedIdentifier = useStateValue(viewmodel.tocActivatedIdentifier$)
  const specifiedTocActivatedIdentifier = useStateValue(viewmodel.specifiedTocActivatedIdentifier$)

  const ast: Root = useMarkdownAst()

  const { visible: visibleScrollToTop, scrollToTop } = useScrollToTop(mainScrollableContainer)
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
    <div className="w-full">
      <div
        className={cn('flex w-full items-start justify-center', {
          'h-[calc(100vh-7rem)]': columns > 1,
        })}
      >
        <div className={cn('fixed right-4 z-50', topbarVisible ? 'top-16' : 'top-4')}>
          <ModeToggle />
        </div>
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
      <button
        onClick={scrollToTop}
        className={cn(
          'cursor-pointer fixed bottom-8 right-8 z-50 flex h-12 w-12 items-center justify-center rounded-full bg-blue-500 bg-opacity-60 text-white shadow-lg transition-all duration-300 hover:bg-blue-600 hover:bg-opacity-100',
          visibleScrollToTop
            ? 'translate-y-0 opacity-90'
            : 'pointer-events-none translate-y-16 opacity-0',
        )}
        title="Scroll to top"
        aria-label="Scroll to top"
      >
        <svg
          xmlns="http://www.w3.org/2000/svg"
          className="h-6 w-6"
          viewBox="0 0 24 24"
          fill="currentColor"
        >
          <path d="M7.41 15.41L12 10.83l4.59 4.58L18 14l-6-6-6 6z" />
        </svg>
      </button>
    </div>
  )
}

Composer.displayName = 'MarkdownViewComposer'
