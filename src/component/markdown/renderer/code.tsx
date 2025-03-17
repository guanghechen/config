import { useStateValue } from '@guanghechen/react-viewmodel'
import type { Code } from '@yozora/ast'
import React from 'react'
import type { ICodeMetaData } from '@/util/parseCodeMeta'
import { parseCodeMeta } from '@/util/parseCodeMeta'
import { useNodeRendererContext } from '../context'
import { CodeRendererInner } from './inner/CodeRendererInner'
import { Mermaid } from './lang/mermaid'

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

  const meta: ICodeMetaData = React.useMemo<ICodeMetaData>(
    () => parseCodeMeta(props.meta || '', { showCodeLineno }),
    [props.meta],
  )

  if (!lang || !meta.live) {
    return (
      <CodeRendererInner
        darken={darken}
        lang={lang ?? 'text'}
        value={value}
        preferCodeWrap={false}
        showCodeLineno={showCodeLineno}
      />
    )
  }

  return (
    <div>
      <div>
        <CodeRendererInner
          darken={darken}
          lang={lang ?? 'text'}
          value={value}
          preferCodeWrap={false}
          showCodeLineno={showCodeLineno}
        />
      </div>
      <div>
        <CodeLiveRenderer lang={lang} code={value} meta={meta} />
      </div>
    </div>
  )
}

interface ICodeLiveRendererProps {
  readonly lang: string
  readonly code: string
  readonly meta: ICodeMetaData
}

export const CodeLiveRenderer: React.FC<ICodeLiveRendererProps> = props => {
  const { lang, code } = props

  switch (lang.toLowerCase()) {
    case 'mermaid':
      return <Mermaid code={code} />
    default:
      return <React.Fragment />
  }
}
