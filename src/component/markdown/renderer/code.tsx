import type { Code } from '@yozora/ast'
import React from 'react'
import type { ICodeMetaData } from '@/util/parseCodeMeta'
import { parseCodeMeta } from '@/util/parseCodeMeta'
import { useMarkdownShowCodeLineNumber } from '../context'
import { Embed } from './embed'
import { CodeResult } from './inner/CodeResult'
import { CodeSource } from './inner/CodeSource'

/**
 * Render `code`
 *
 * @see https://www.npmjs.com/package/@yozora/ast#code
 * @see https://www.npmjs.com/package/@yozora/tokenizer-indented-code
 * @see https://www.npmjs.com/package/@yozora/tokenizer-fenced-code
 */
export const CodeRenderer: React.FC<Code> = props => {
  const { lang } = props
  const code: string = props.value.replace(/[\n\r]+$/, '') // Remove trailing line endings.

  const showCodeLineno: boolean = useMarkdownShowCodeLineNumber()

  const meta: ICodeMetaData = React.useMemo<ICodeMetaData>(
    () => parseCodeMeta(props.meta || '', { showCodeLineno }),
    [props.meta, showCodeLineno],
  )

  if (!!lang && !!meta.live) {
    return (
      <div className="yozora-code my-4 flex flex-col overflow-hidden rounded-lg border border-gray-200 shadow-md dark:border-gray-600">
        <CodeSource
          code={code}
          lang={lang}
          meta={meta}
          showLineno={showCodeLineno}
          initialExpanded={typeof meta.collapsed === 'boolean' ? !meta.collapsed : true}
        />
        <CodeResult code={code} lang={lang!} meta={meta} />
      </div>
    )
  }

  if (!!lang && !!meta.embed) {
    return (
      <div className="yozora-code flex items-center justify-center p-4">
        <Embed lang={lang} code={code} meta={meta} />
      </div>
    )
  }

  return (
    <div className="yozora-code my-4 flex flex-col overflow-hidden rounded-lg border border-gray-200 shadow-md dark:border-gray-600">
      <CodeSource
        code={code}
        lang={lang}
        meta={meta}
        showLineno={showCodeLineno}
        initialExpanded={typeof meta.collapsed === 'boolean' ? !meta.collapsed : undefined}
      />
    </div>
  )
}

CodeRenderer.displayName = 'YozoraCode'
