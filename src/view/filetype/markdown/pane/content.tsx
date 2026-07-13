import { useStateValue } from '@guanghechen/react-viewmodel'
import type { Heading, Root } from '@yozora/ast'
import type { IHeadingToc, IHeadingTocNode } from '@yozora/ast-util'
import cn from 'clsx'
import React from 'react'
import { NodesRenderer, ReactMarkdown, useMarkdownAst } from '@/container/markdown'
import { ReactMarkdownContent } from '@/container/markdown/ReactMarkdownContent'
import { useMarkdownViewViewModel } from '../context'

interface IHeadingPosition {
  readonly identifier: string
  readonly element: HTMLElement
  top: number
}

type IScrollContainer = HTMLElement | Window

const TOC_ACTIVATION_VIEWPORT_OFFSET = 48

const isElementScrollContainer = (container: IScrollContainer): container is HTMLElement =>
  container instanceof HTMLElement

const resolveScrollContainer = (element: HTMLElement): IScrollContainer => {
  let current: HTMLElement | null = element.parentElement
  while (current) {
    const { overflowY } = window.getComputedStyle(current)
    if (overflowY === 'auto' || overflowY === 'scroll') return current
    current = current.parentElement
  }
  return window
}

const getScrollTop = (container: IScrollContainer): number =>
  isElementScrollContainer(container) ? container.scrollTop : window.scrollY

const getScrollViewportTop = (container: IScrollContainer): number =>
  isElementScrollContainer(container) ? container.getBoundingClientRect().top : 0

const findActivatedIdentifier = (
  headings: ReadonlyArray<IHeadingPosition>,
  boundary: number,
): string | null => {
  let low = 0
  let high = headings.length
  while (low < high) {
    const middle = low + ((high - low) >> 1)
    if (headings[middle].top < boundary) low = middle + 1
    else high = middle
  }
  return headings[low]?.identifier ?? null
}

export const ContentPane: React.FC = () => {
  const viewmodel = useMarkdownViewViewModel()
  const data = useStateValue(viewmodel.data$)
  const contentFullWidth: boolean = useStateValue(viewmodel.contentFullWidth$)

  const ast: Root = useMarkdownAst()
  const toc: IHeadingToc | undefined = data?.toc
  const frontmatter: Record<string, unknown> | undefined = data?.frontmatter
  const frontmatterTitle =
    typeof frontmatter?.title === 'string' ? frontmatter.title.trim() : undefined
  const frontmatterSubtitle =
    typeof frontmatter?.subtitle === 'string' ? frontmatter.subtitle.trim() : undefined
  const titleClassName = 'text-center text-3xl font-bold text-gray-900 dark:text-white'

  const containerRef = React.useRef<HTMLDivElement | null>(null)
  const timerRef = React.useRef<ReturnType<typeof setTimeout> | null>(null)
  const lastActivatedIdentifierRef = React.useRef<string | null>(null)

  let title: React.ReactElement
  if (
    !frontmatterTitle &&
    ast.children[0].type === 'heading' &&
    (ast.children[0] as Heading).depth === 1
  ) {
    const heading: Heading = ast.children[0] as Heading
    title = (
      <h1 className={`yozora-root ${titleClassName}`}>
        <NodesRenderer nodes={heading.children} />
      </h1>
    )
  } else {
    title = (
      <ReactMarkdownContent
        Tag="h1"
        className={titleClassName}
        content={frontmatterTitle || 'Untitled'}
      />
    )
  }

  React.useEffect(() => {
    const contentContainer: HTMLDivElement | null = containerRef.current
    if (!contentContainer || !toc) return

    const scrollContainer = resolveScrollContainer(contentContainer)

    const headings: IHeadingPosition[] = []
    const collect = (item: IHeadingTocNode): void => {
      const identifier: string = encodeURIComponent(item.identifier)
      const element: HTMLElement | null = document.getElementById(identifier)
      if (element) headings.push({ identifier: item.identifier, element, top: 0 })
      for (const child of item.children) collect(child)
    }
    for (const child of toc.children) collect(child)

    let scrollViewportTop = 0
    let animationFrame: number | null = null
    let measurementPending = false

    const flushSpecifiedActivation = (): void => {
      const specifiedTocIdentifier: string | null =
        viewmodel.specifiedTocActivatedIdentifier$.getSnapshot()
      if (specifiedTocIdentifier === null) return
      viewmodel.specifiedTocActivatedIdentifier$.next(null)
      lastActivatedIdentifierRef.current = specifiedTocIdentifier
      viewmodel.tocActivatedIdentifier$.next(specifiedTocIdentifier)
    }

    const scheduleSpecifiedActivation = (): void => {
      if (timerRef.current !== null) return
      if (viewmodel.specifiedTocActivatedIdentifier$.getSnapshot() === null) return
      timerRef.current = setTimeout(() => {
        timerRef.current = null
        flushSpecifiedActivation()
      }, 72)
    }

    const updateActivatedIdentifier = (): void => {
      const boundary =
        getScrollTop(scrollContainer) + TOC_ACTIVATION_VIEWPORT_OFFSET - scrollViewportTop
      const nextTocActivatedIdentifier = findActivatedIdentifier(headings, boundary)

      if (lastActivatedIdentifierRef.current !== nextTocActivatedIdentifier) {
        lastActivatedIdentifierRef.current = nextTocActivatedIdentifier
        viewmodel.tocActivatedIdentifier$.next(nextTocActivatedIdentifier)
      }

      scheduleSpecifiedActivation()
    }

    const flushUpdate = (): void => {
      animationFrame = null
      if (measurementPending) {
        measurementPending = false
        const scrollTop = getScrollTop(scrollContainer)
        scrollViewportTop = getScrollViewportTop(scrollContainer)
        for (const heading of headings) {
          heading.top = heading.element.getBoundingClientRect().top - scrollViewportTop + scrollTop
        }
      }
      updateActivatedIdentifier()
    }

    const scheduleUpdate = (measure: boolean): void => {
      if (measure) measurementPending = true
      if (animationFrame === null) animationFrame = requestAnimationFrame(flushUpdate)
    }

    const onScroll = (): void => scheduleUpdate(false)
    const onResize = (): void => scheduleUpdate(true)
    const resizeObserver = new ResizeObserver(onResize)
    resizeObserver.observe(contentContainer)
    if (isElementScrollContainer(scrollContainer)) resizeObserver.observe(scrollContainer)

    scheduleUpdate(true)
    scrollContainer.addEventListener('scroll', onScroll, { passive: true })
    window.addEventListener('resize', onResize, { passive: true })
    return () => {
      scrollContainer.removeEventListener('scroll', onScroll)
      window.removeEventListener('resize', onResize)
      resizeObserver.disconnect()
      if (animationFrame !== null) cancelAnimationFrame(animationFrame)
      if (timerRef.current) {
        clearTimeout(timerRef.current)
        timerRef.current = null
      }
    }
  }, [toc, viewmodel])

  return (
    <div
      ref={containerRef}
      className={cn('flex-auto', contentFullWidth ? 'max-w-none' : 'max-w-[72rem]')}
    >
      <div className="px-8 py-4">
        <header
          className={`${
            frontmatterSubtitle ? 'mb-6' : 'mb-4'
          } flex w-full flex-col items-center text-center`}
        >
          {title}
          {frontmatterSubtitle && (
            <div className="mt-1 flex w-full justify-end">
              <p className="text-base text-gray-600 dark:text-gray-400">{frontmatterSubtitle}</p>
            </div>
          )}
        </header>
        <ReactMarkdown ast={ast} dontShowFirstHeading={true} />
      </div>
    </div>
  )
}

ContentPane.displayName = 'MarkdownViewContentPane'
