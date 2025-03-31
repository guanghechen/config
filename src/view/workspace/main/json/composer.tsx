import { useStateValue } from '@guanghechen/react-viewmodel'
import CodeHighlighter from '@yozora/react-code-highlighter'
import cn from 'clsx'
import JSON5 from 'json5'
import React from 'react'
import { Json } from '@/component/json'
import { PRESET_CLASSES } from '@/constant/classes'
import { SiteTheme, useSiteViewmodel } from '@/context/site'
import { JsonModeEnum, useWorkspaceViewmodel } from '@/context/workspace'

interface IProps {
  readonly content: string | undefined
}

const DEFAULT_JSON = {
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

export const JsonComposer: React.FC<IProps> = props => {
  const { content } = props
  const siteVM = useSiteViewmodel()
  const workspaceVM = useWorkspaceViewmodel()
  const mode: JsonModeEnum = useStateValue(workspaceVM.jsonMode$)
  const theme: SiteTheme = useStateValue(siteVM.theme$)

  const showView: boolean = mode === 0 || (mode & JsonModeEnum.VIEW) !== 0
  const showLiteral: boolean = (mode & JsonModeEnum.LITERAL) !== 0
  const columns: number = (showView ? 1 : 0) + (showLiteral ? 1 : 0)

  const json = React.useMemo<unknown>(
    () => (typeof content === 'string' ? JSON5.parse(content) : DEFAULT_JSON),
    [content],
  )

  return (
    <div
      className={cn('flex w-full items-start justify-center pb-8', {
        'h-[calc(100vh-6rem)]': columns > 1,
      })}
    >
      {showView && (
        <React.Fragment>
          <div
            className={cn('h-full w-[72rem] max-w-[100rem] flex-auto', PRESET_CLASSES.scrollbar, {
              'p-2 overflow-auto': columns > 1,
            })}
          >
            <Json json={json} />
          </div>
          {columns > 1 && <div className="mx-2 h-full flex-shrink-0 border-r border-gray-300" />}
        </React.Fragment>
      )}
      {showLiteral && (
        <div
          className={cn(
            'h-full w-[48rem] max-w-[100rem] flex-auto border border-gray-200',
            PRESET_CLASSES.scrollbar,
            {
              'p-2 overflow-auto': columns > 1,
            },
          )}
        >
          <CodeHighlighter
            darken={theme === SiteTheme.DARKEN}
            lang="json"
            value={content || ''}
            collapsed={false}
            showLineNo={true}
            className={PRESET_CLASSES.scrollbar}
            codesClassName={PRESET_CLASSES.scrollbar}
          />
        </div>
      )}
    </div>
  )
}

JsonComposer.displayName = 'JsonComposer'
