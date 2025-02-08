import { useStateValue } from '@guanghechen/react-viewmodel'
import type { Code } from '@yozora/ast'
import React from 'react'
import type { IReactMarkdownThemeScheme } from '../context'
import { useNodeRendererContext } from '../context'
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
  const themeScheme: IReactMarkdownThemeScheme = useStateValue(viewmodel.themeScheme$)
  const darken: boolean = themeScheme === 'darken'

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
