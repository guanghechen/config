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
  const themeScheme: string = useStateValue(viewmodel.themeScheme$)
  const darken: boolean = themeScheme === 'darken'

  const meta: ICodeMetaData = React.useMemo<ICodeMetaData>(
    () => parseCodeMeta(props.meta || '', { showCodeLineno }),
    [props.meta],
  )

  const hasPreview: boolean = !!lang && !!meta.live
  return (
    <div className="flex flex-col my-4 rounded-lg overflow-hidden shadow-md">
      <CodeSource
        darken={darken}
        code={code}
        lang={lang}
        meta={meta}
        showLineNo={showCodeLineno}
        initialExpanded={!hasPreview}
      />
      {hasPreview && <CodeResult darken={darken} code={code} lang={lang!} meta={meta} />}
    </div>
  )
}
