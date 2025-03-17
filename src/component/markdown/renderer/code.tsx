import { useStateValue } from '@guanghechen/react-viewmodel'
import type { Code } from '@yozora/ast'
import React, { useState } from 'react'
import { CodeIcon, TerminalIcon } from '@/component/icon/material'
import type { ICodeMetaData } from '@/util/parseCodeMeta'
import { parseCodeMeta } from '@/util/parseCodeMeta'
import { useNodeRendererContext } from '../context'
import { CodeLiveRenderer } from './inner/CodeLive'
import { CodeRendererInner } from './inner/CodeRendererInner'

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

  const toggleSourceExpanded = React.useCallback(() => setIsSourceExpanded(v => !v), [])
  const toggleResultExpanded = React.useCallback(() => setIsResultExpanded(v => !v), [])
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
      <div className={isSourceExpanded ? 'border-b border-opacity-10 border-black' : ''}>
        <div
          className={`flex justify-between items-center p-2 px-4 cursor-pointer select-none ${
            darken ? 'bg-[#2d2d2d]' : 'bg-gray-100'
          } ${isSourceExpanded ? 'border-b border-opacity-10 border-black' : ''}`}
          onClick={toggleSourceExpanded}
        >
          <div className="flex items-center gap-2">
            <CodeIcon className="w-[18px] h-[18px] opacity-80" />
            <span
              className={`px-1.5 py-0.5 rounded text-xs ${darken ? 'bg-[#444]' : 'bg-gray-200'}`}
            >
              {lang}
            </span>
            {title && <span className="text-sm">{title}</span>}
          </div>
        </div>
        {isSourceExpanded && (
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
        )}
      </div>
      <div>
        <div
          className={`flex justify-between items-center p-2 px-4 cursor-pointer select-none ${
            darken ? 'bg-[#2d2d2d]' : 'bg-gray-100'
          } ${isResultExpanded ? 'border-b border-opacity-10 border-black' : ''}`}
          onClick={toggleResultExpanded}
        >
          <div className="flex items-center gap-2">
            <TerminalIcon className="w-[18px] h-[18px] opacity-80" />
            <span className="text-sm">Result</span>
          </div>
        </div>
        {isResultExpanded && (
          <div className="p-4 flex justify-center items-center">
            <CodeLiveRenderer lang={lang} code={value} meta={meta} />
          </div>
        )}
      </div>
    </div>
  )
}
