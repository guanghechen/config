import { useStateValue } from '@guanghechen/react-viewmodel'
import type { Code } from '@yozora/ast'
import React from 'react'
import type { ICodeMetaData } from '@/util/parseCodeMeta'
import { parseCodeMeta } from '@/util/parseCodeMeta'
import { useNodeRendererContext } from '../context'
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

  const { viewmodel } = useNodeRendererContext()
  const showCodeLineno: boolean = useStateValue(viewmodel.showCodeLineno$)

  const meta: ICodeMetaData = React.useMemo<ICodeMetaData>(
    () => parseCodeMeta(props.meta || '', { showCodeLineno }),
    [props.meta],
  )

  const hasPreview: boolean = !!lang && !!meta.live
  return (
    <div className="my-4 flex flex-col overflow-hidden rounded-lg shadow-md">
      <CodeSource
        code={code}
        lang={lang}
        meta={meta}
        showLineNo={showCodeLineno}
        initialExpanded={!hasPreview}
      />
      {hasPreview && <CodeResult code={code} lang={lang!} meta={meta} />}
    </div>
  )
}
