import { useStateValue } from '@guanghechen/react-viewmodel'
import type { Heading, Root } from '@yozora/ast'
import type { IHeadingToc, IHeadingTocNode } from '@yozora/ast-util'
import throttle from 'lodash.throttle'
import React from 'react'
import { NodesRenderer, ReactMarkdown, useMarkdownAst } from '@/container/markdown'
import { ReactMarkdownContent } from '@/container/markdown/ReactMarkdownContent'
import { useMarkdownViewViewModel } from '../context'

export const ContentPane: React.FC = () => {
  const viewmodel = useMarkdownViewViewModel()
  const data = useStateValue(viewmodel.data$)

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

    const scrollContainer: HTMLElement =
      (contentContainer.closest('.vlm-pane') as HTMLElement | null) ?? contentContainer

    const identifiers: Array<[string, HTMLElement]> = []
    const collect = (item: IHeadingTocNode): void => {
      const identifier: string = encodeURIComponent(item.identifier)
      const element: HTMLElement | null = document.getElementById(identifier)
      if (element) identifiers.push([item.identifier, element])
      for (const child of item.children) collect(child)
    }
    for (const child of toc.children) collect(child)

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
      const viewportTopOffset: number = 48
      let nextTocActivatedIdentifier: string | null = null
      for (const [identifier, element] of identifiers) {
        if (element.getBoundingClientRect().top >= viewportTopOffset) {
          nextTocActivatedIdentifier = identifier
          break
        }
      }

      if (lastActivatedIdentifierRef.current !== nextTocActivatedIdentifier) {
        lastActivatedIdentifierRef.current = nextTocActivatedIdentifier
        viewmodel.tocActivatedIdentifier$.next(nextTocActivatedIdentifier)
      }

      scheduleSpecifiedActivation()
    }

    const onScroll = throttle(updateActivatedIdentifier, 120, {
      leading: true,
      trailing: true,
    })

    updateActivatedIdentifier()
    scrollContainer.addEventListener('scroll', onScroll, { passive: true })
    return () => {
      scrollContainer.removeEventListener('scroll', onScroll)
      onScroll.cancel()
      if (timerRef.current) {
        clearTimeout(timerRef.current)
        timerRef.current = null
      }
    }
  }, [toc, viewmodel])

  return (
    <div ref={containerRef} className="flex-auto max-w-[72rem]">
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
