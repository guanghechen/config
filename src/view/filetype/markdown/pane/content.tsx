import { useStateValue } from '@guanghechen/react-viewmodel'
import type { Heading, Root } from '@yozora/ast'
import type { IHeadingToc, IHeadingTocNode } from '@yozora/ast-util'
import throttle from 'lodash.throttle'
import React from 'react'
import { NodesRenderer, ReactMarkdown, useMarkdownAst } from '@/component/markdown'
import { ReactMarkdownContent } from '@/component/markdown/ReactMarkdownContent'
import { useMarkdownViewViewModel } from '../context'

export const ContentPane: React.FC = () => {
  const viewmodel = useMarkdownViewViewModel()
  const data = useStateValue(viewmodel.data$)

  const ast: Root = useMarkdownAst()
  const toc: IHeadingToc | undefined = data?.toc
  const frontmatter: Record<string, unknown> | undefined = data?.frontmatter

  const containerRef = React.useRef<HTMLDivElement | null>(null)
  const timerRef = React.useRef<ReturnType<typeof setTimeout> | null>(null)

  let title: React.ReactElement
  if (
    !frontmatter?.title &&
    ast.children[0].type === 'heading' &&
    (ast.children[0] as Heading).depth === 1
  ) {
    const heading: Heading = ast.children[0] as Heading
    title = (
      <h1 className="yozora-root">
        <NodesRenderer nodes={heading.children} />
      </h1>
    )
  } else {
    title = <ReactMarkdownContent Tag="h1" content={(frontmatter?.title as string) || 'Untitled'} />
  }

  React.useEffect(() => {
    const contentContainer: HTMLDivElement | null = containerRef.current
    if (!contentContainer || !toc) return

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

      if (timerRef.current) {
        clearTimeout(timerRef.current)
        timerRef.current = setTimeout(() => {
          timerRef.current = null
          const specifiedTocIdentifier: string | null =
            viewmodel.specifiedTocActivatedIdentifier$.getSnapshot()
          if (specifiedTocIdentifier !== null) {
            viewmodel.specifiedTocActivatedIdentifier$.next(null)
            viewmodel.tocActivatedIdentifier$.next(specifiedTocIdentifier)
          }
        }, 72)
      }
    }, 50)

    onScroll()
    contentContainer.addEventListener('scroll', onScroll)
    return () => contentContainer.removeEventListener('scroll', onScroll)
  }, [toc, viewmodel])

  return (
    <div ref={containerRef} className="flex-auto max-w-[72rem]">
      <div className="px-8 py-4">
        <div className="mb-4 flex justify-center text-3xl font-bold text-gray-900 dark:text-white">
          {title}
        </div>
        <ReactMarkdown ast={ast} dontShowFirstHeading={true} />
      </div>
    </div>
  )
}

ContentPane.displayName = 'MarkdownViewContentPane'
