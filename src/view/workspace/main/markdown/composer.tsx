import { useStateValue } from '@guanghechen/react-viewmodel'
import type { Root } from '@yozora/ast'
import React from 'react'
import { Json } from '@/component/json'
import { ReactMarkdown } from '@/component/markdown'
import type { SiteTheme } from '@/context/site'
import { useSiteViewmodel } from '@/context/site'
import { MarkdownModeEnum, useWorkspaceViewmodel } from '../../context'

interface IProps {
  readonly ast: Root
}

const json = {
  empty: {
    a: {},
    b: [],
    story:
      "Once upon a time in a small coastal village, a young fisher named Maya discovered an unusual bottle washed ashore. Inside was a map leading to a hidden cove. Curiosity sparked, she sailed at dawn, navigating treacherous waters until reaching the secluded bay. There stood an ancient lighthouse, abandoned for decades. Inside, she found journals detailing the life of a lonely keeper who had discovered how to communicate with whales through music. Maya restored the lighthouse and learned his methods. Soon, whales returned to the waters, bringing prosperity to her village. Years later, tourists would visit to hear Maya's enchanting melodies and watch as massive creatures danced in the waves, a testament to how one unexpected discovery can transform a life and community forever.",
  },
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
  const { ast } = props
  const siteVM = useSiteViewmodel()
  const workspaceVM = useWorkspaceViewmodel()
  const mode: MarkdownModeEnum = useStateValue(workspaceVM.markdownMode$)
  const theme: SiteTheme = useStateValue(siteVM.theme$)

  switch (mode) {
    case MarkdownModeEnum.PREVIEW:
      return (
        <div className="flex w-full justify-center">
          <div className="w-[80rem] flex-shrink flex-grow-0 p-4">
            <ReactMarkdown ast={ast} theme={theme} />
          </div>
        </div>
      )
    case MarkdownModeEnum.AST:
      return (
        <div className="flex w-full justify-center">
          <div className="w-[60rem] flex-shrink flex-grow-0 p-4">
            <Json json={ast || json} />
          </div>
        </div>
      )
    case MarkdownModeEnum.SBS:
      return (
        <div className="flex h-[calc(100vh-5rem)] items-start justify-center p-4">
          <div className="h-full w-[80rem] flex-shrink flex-grow-0 overflow-auto">
            <ReactMarkdown ast={ast} theme={theme} />
          </div>
          <div className="mx-6 h-full flex-shrink-0 border-r border-gray-300" />
          <div className="h-full w-[60rem] flex-shrink flex-grow-0 overflow-auto">
            <Json json={ast || json} />
          </div>
        </div>
      )
  }
}

MarkdownComposer.displayName = 'MarkdownComposer'
