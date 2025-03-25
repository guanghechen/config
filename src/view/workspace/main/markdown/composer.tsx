import { useStateValue } from '@guanghechen/react-viewmodel'
import type { Root } from '@yozora/ast'
import type { IHeadingToc } from '@yozora/ast-util'
import cn from 'clsx'
import React from 'react'
import { Json } from '@/component/json'
import { MarkdownProvider, MarkdownToc, ReactMarkdown } from '@/component/markdown'
import type { SiteTheme } from '@/context/site'
import { useSiteViewmodel } from '@/context/site'
import { MarkdownModeEnum, useWorkspaceViewmodel } from '../../context'

interface IProps {
  readonly ast: Root
  readonly toc: IHeadingToc | undefined
  readonly frontmatter: Record<string, unknown> | undefined
}

const json = {
  empty: {
    a: {},
    b: [],
    story:
      "Once upon a time in a small coastal village, a young fisher named Maya discovered an unusual bottle washed ashore. Inside was a map leading to a hidden cove. Curiosity sparked, she sailed at dawn, navigating treacherous waters until reaching the secluded bay. There stood an ancient lighthouse, abandoned for decades. Inside, she found journals detailing the life of a lonely keeper who had discovered how to communicate with whales through music. Maya restored the lighthouse and learned his methods. Soon, whales returned to the waters, bringing prosperity to her village. Years later, tourists would visit to hear Maya's enchanting melodies and watch as massive creatures danced in the waves, a testament to how one unexpected discovery can transform a life and community forever.",
  },
  nums: Array.from(new Array(300))
    .map((_, i): unknown => i)
    .concat({ a: 1, b: 2, c: 3, d: { e: 5, f: 7 }, g: [10, 11, '23'] }),
  name: 'lemon',
  age: 10,
  address: ['a', 'bc', 'def'],
  others: {
    favirate: [
      'apple',
      'banana',
      {
        name: 'orange',
        variants: ['italic', 'bold'],
      },
    ],
    subjects: {
      science: 'A',
    },
  },
  values: {
    undefined: undefined,
    null: null,
    integer: 1,
    number: 0.2,
    string: 'hello, world!',
    symbol: Symbol.for('lemoncat'),
    bigint: 20n,
  },
  methods: {
    GET: function (a: string, b: number, c: bigint, d: symbol, e: null, f: undefined): string {
      return [a, b, c, d, e, f].join(',')
    },
    POST: (a: string, b: number, c: bigint, d: symbol, e: null, f: undefined): string =>
      [a, b, c, d, e, f].join(','),
    PUT: () => {},
  },
}

export const MarkdownComposer: React.FC<IProps> = props => {
  const { ast, toc, frontmatter } = props
  const siteVM = useSiteViewmodel()
  const workspaceVM = useWorkspaceViewmodel()
  const mode: MarkdownModeEnum = useStateValue(workspaceVM.markdownMode$)
  const theme: SiteTheme = useStateValue(siteVM.theme$)

  const showView: boolean = mode === 0 || (mode & MarkdownModeEnum.VIEW) !== 0
  const showAst: boolean = (mode & MarkdownModeEnum.AST) !== 0
  const showToc: boolean = (mode & MarkdownModeEnum.TOC) !== 0
  const count: number = (showView ? 1 : 0) + (showAst ? 1 : 0) + (showToc ? 1 : 0)

  return (
    <MarkdownProvider ast={ast} theme={theme}>
      <div className="flex h-[calc(100vh-5rem)] w-full items-start justify-center p-4">
        {showView && (
          <React.Fragment>
            <div
              className={cn('h-full w-[72rem] flex-initial', {
                'p-2 overflow-auto': count > 1,
              })}
            >
              <ReactMarkdown />
            </div>
            {count > 1 && <div className="mx-2 h-full flex-shrink-0 border-r border-gray-300" />}
          </React.Fragment>
        )}
        {showAst && (
          <React.Fragment>
            <div
              className={cn('h-full w-[48rem] flex-initial', {
                'p-2 overflow-auto': count > 1,
              })}
            >
              <Json json={ast || json} />
            </div>
            {showToc && <div className="mx-2 h-full flex-shrink-0 border-r border-gray-300" />}
          </React.Fragment>
        )}
        {showToc && (
          <div
            className={cn('flex h-full justify-center', {
              'w-[32rem] flex-col flex-initial': count > 1,
            })}
          >
            <div
              className={cn('flex-auto basis-0 overflow-auto p-2', {
                'flex justify-center': count === 1,
              })}
            >
              <h3 className="mb-4 text-lg font-medium text-gray-800 dark:text-gray-100">
                Table of Contents
              </h3>
              <MarkdownToc toc={toc} />
            </div>
            <div
              className={cn('flex-shrink-0 border-gray-300', {
                'mx-2 h-full border-r': count === 1,
                'my-2 w-full border-b': count > 1,
              })}
            />
            <div
              className={cn('flex-auto basis-0 overflow-auto p-2', {
                'flex justify-center': count === 1,
              })}
            >
              <h3 className="mb-4 text-lg font-medium text-gray-800 dark:text-gray-100">
                Frontmatter
              </h3>
              <Json json={frontmatter} />
            </div>
          </div>
        )}
      </div>
    </MarkdownProvider>
  )
}

MarkdownComposer.displayName = 'MarkdownComposer'
