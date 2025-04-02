import React from 'react'
import vscDarkTheme from '../theme/vsc-dark'
import vscLightTheme from '../theme/vsc-light'
import type { IPrismTheme } from '../types'
import { HighlightContent } from './HighlightContent'

interface IProps {
  /**
   * Source code contents
   */
  readonly value: string
  /**
   * Code language
   */
  readonly lang?: string | null
  /**
   * Line number of Lines that should be highlighted.
   */
  readonly highlightLinenos?: number[]
  /**
   * Whether the code block is in a collapsed state.
   * @default false
   */
  readonly collapsed?: boolean
  /**
   * Maximum number of rows displayed
   * @default -1
   */
  readonly maxLines?: number
  /**
   * Whether should display line numbers.
   * @default true
   */
  readonly showLineNo?: boolean
  /**
   * If true, use vscDarkTheme as default theme,
   * otherwise use vscLightTheme as default theme.
   * @default true
   */
  readonly darken?: boolean
  /**
   * Highlight prism theme.
   */
  readonly theme?: IPrismTheme
  /**
   * Ref of the codes area.
   */
  readonly codesRef?: React.RefCallback<HTMLDivElement> | React.RefObject<HTMLDivElement>
  /**
   * Custom css class for the container.
   */
  readonly className?: string
  /**
   * Custom css class for the codes area.
   */
  readonly codesClassName?: string
  /**
   * Callback when linenoWidth changed.
   */
  readonly onLinenoWidthChange?: (linenoWidth: React.CSSProperties['width']) => void
}

export class CodeHighlighter extends React.PureComponent<IProps> {
  public static readonly displayName = 'YozoraCodeHighlighter'

  public override render(): React.ReactElement {
    const {
      lang,
      value: code,
      darken = true,
      highlightLinenos = [],
      maxLines = -1,
      collapsed = false,
      showLineNo = true,
      codesRef,
      onLinenoWidthChange,
      className,
      codesClassName,
    } = this.props

    const theme: IPrismTheme = this.props.theme ?? (darken ? vscDarkTheme : vscLightTheme)
    return (
      <HighlightContent
        code={code}
        codesRef={codesRef}
        collapsed={collapsed}
        highlightLinenos={highlightLinenos}
        language={lang ?? ''}
        maxLines={maxLines}
        showLineno={showLineNo}
        theme={theme}
        onLinenoWidthChange={onLinenoWidthChange}
        className={className}
        codesClassName={codesClassName}
      />
    )
  }
}
