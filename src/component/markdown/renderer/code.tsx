import { useStateValue } from '@guanghechen/react-viewmodel'
import type { Code } from '@yozora/ast'
import cn from 'clsx'
import React, { useState } from 'react'
import { CodeIcon, TerminalIcon } from '@/component/icon/material'
import type { ICodeMetaData } from '@/util/parseCodeMeta'
import { parseCodeMeta } from '@/util/parseCodeMeta'
import { useNodeRendererContext } from '../context'
import { CodeLiveRenderer } from './inner/CodeLive'
import { CodeRendererInner } from './inner/CodeRendererInner'

interface ICodeSourceInfoProps {
  readonly darken: boolean
  readonly lang: string
  readonly title: string | undefined
}

const CodeSourceInfo: React.FC<ICodeSourceInfoProps> = props => {
  const { darken, lang, title } = props
  return (
    <div className="flex items-center gap-2">
      {title && <span className="text-sm text-indigo-600 dark:text-indigo-400">{title}</span>}
      <CodeIcon className="w-[18px] h-[18px] opacity-80" />
      <span
        className={cn('px-1.5 py-0.5 rounded text-xs', {
          'bg-[#444]': darken,
          'bg-gray-200': !darken,
        })}
      >
        {lang}
      </span>
    </div>
  )
}

interface ICodeResultInfoProps {
  readonly title: string | undefined
}

const CodeResultInfo: React.FC<ICodeResultInfoProps> = props => {
  const { title } = props
  return (
    <div className="flex items-center gap-2">
      {title && <span className="text-sm text-indigo-600 dark:text-indigo-400">{title}</span>}
      <TerminalIcon className="w-[18px] h-[18px] opacity-80" />
      <span className="text-sm">Result</span>
    </div>
  )
}

/**
 * Render `code`
 *
 * @see https://www.npmjs.com/package/@yozora/ast#code
 * @see https://www.npmjs.com/package/@yozora/tokenizer-indented-code
 * @see https://www.npmjs.com/package/@yozora/tokenizer-fenced-code
 */
export const CodeRenderer: React.FC<Code> = props => {
  const { lang } = props
  const value: string = props.value.replace(/[\n\r]+$/, '') // Remove trailing line endings.

  const { viewmodel } = useNodeRendererContext()
  const showCodeLineno: boolean = useStateValue(viewmodel.showCodeLineno$)
  const themeScheme: string = useStateValue(viewmodel.themeScheme$)
  const darken: boolean = themeScheme === 'darken'
  const [isSourceExpanded, setIsSourceExpanded] = useState(false)
  const [isResultExpanded, setIsResultExpanded] = useState(true)

  const meta: ICodeMetaData = React.useMemo<ICodeMetaData>(
    () => parseCodeMeta(props.meta || '', { showCodeLineno }),
    [props.meta],
  )

  const onSourceToggled = React.useCallback(() => setIsSourceExpanded(v => !v), [])
  const onResultToggled = React.useCallback(() => setIsResultExpanded(v => !v), [])
  const title: string = (meta.filename || meta.title || '') as string

  if (!lang || !meta.live) {
    return (
      <CodeRendererInner
        darken={darken}
        lang={lang || ''}
        value={value}
        preferCodeWrap={false}
        showCodeLineno={showCodeLineno}
      />
    )
  }

  return (
    <div className="my-4 rounded-lg overflow-hidden shadow-md">
      <div
        className={cn({
          'border-b border-opacity-10 border-black': isSourceExpanded,
        })}
      >
        {isSourceExpanded ? (
          <React.Fragment>
            <div
              className={cn(
                'flex justify-between items-center p-2 px-4 cursor-pointer select-none',
                {
                  'bg-[#2d2d2d]': darken,
                  'bg-gray-100': !darken,
                  'border-b border-opacity-10 border-black': isSourceExpanded,
                },
              )}
              onClick={onSourceToggled}
            >
              <CodeSourceInfo darken={darken} lang={lang} title={title} />
            </div>
            <div className="source-content">
              <CodeRendererInner
                darken={darken}
                lang={lang}
                value={value}
                preferCodeWrap={false}
                showCodeLineno={showCodeLineno}
                style={{ marginBottom: 0 }}
              />
            </div>
          </React.Fragment>
        ) : (
          <div
            className={cn('flex items-center p-2 px-4 cursor-pointer select-none', {
              'bg-[#2d2d2d]': darken,
              'bg-gray-100': !darken,
              'border-b border-opacity-10 border-black': isSourceExpanded,
              'flex-row-reverse': !isSourceExpanded && isResultExpanded,
            })}
          >
            <div
              className={isSourceExpanded || !isResultExpanded ? 'flex-auto' : 'flex-initial'}
              onClick={onSourceToggled}
            >
              <CodeSourceInfo
                darken={darken}
                lang={lang}
                title={!isSourceExpanded && isResultExpanded ? undefined : title}
              />
            </div>
            <div
              className={!isSourceExpanded && isResultExpanded ? 'flex-auto' : 'flex-initial'}
              onClick={onResultToggled}
            >
              <CodeResultInfo title={!isSourceExpanded && isResultExpanded ? title : undefined} />
            </div>
          </div>
        )}
      </div>
      <div>
        {isResultExpanded && isSourceExpanded && (
          <div
            className={cn('flex justify-between items-center p-2 px-4 cursor-pointer select-none', {
              'bg-[#2d2d2d]': darken,
              'bg-gray-100': !darken,
              'border-b border-opacity-10 border-black': isResultExpanded,
            })}
            onClick={onResultToggled}
          >
            <CodeResultInfo title={undefined} />
          </div>
        )}
        {isResultExpanded && (
          <div className="p-4 flex justify-center items-center">
            <CodeLiveRenderer lang={lang} code={value} meta={meta} />
          </div>
        )}
      </div>
    </div>
  )
}
