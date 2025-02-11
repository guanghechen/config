import { css, cx } from '@emotion/css'
import CodeHighlighter from '@yozora/react-code-highlighter'
import React from 'react'
import { astClasses } from '../../context'
import { CopyButton } from './CopyButton'

interface IProps {
  readonly darken: boolean
  readonly lang: string
  readonly value: string
  readonly preferCodeWrap: boolean
  readonly showCodeLineno: boolean
  readonly pendingText?: string
  readonly copyingText?: string
  readonly copiedText?: string
  readonly failedText?: string
}

export class CodeRendererInner extends React.PureComponent<IProps> {
  public override render(): React.ReactElement {
    const { calcContentForCopy } = this
    const { darken, lang, value, preferCodeWrap, showCodeLineno } = this.props

    return (
      <code className={codeCls} data-wrap={preferCodeWrap}>
        <CodeHighlighter
          lang={lang}
          value={value}
          collapsed={false}
          showLineNo={showCodeLineno && !preferCodeWrap}
          darken={darken}
        />
        <div className={copyButtonCls}>
          <CopyButton calcContentForCopy={calcContentForCopy} />
        </div>
      </code>
    )
  }

  protected calcContentForCopy = (): string => {
    return this.props.value
  }
}

const copyButtonCls = css({
  position: 'absolute',
  right: '4px',
  top: '4px',
  display: 'none',
})

const codeCls = cx(
  astClasses.code,
  css({
    position: 'relative',
    display: 'block',
    boxSizing: 'border-box',
    borderRadius: '4px',
    margin: '0px 0px 1.25em 0px',
    fontFamily: 'var(--fontFamilyCode)',
    backgroundColor: 'var(--colorBgCode)',
    [`&:hover > .${copyButtonCls}`]: {
      display: 'inline-block',
    },
    '&&[data-wrap="true"] > div': {
      whiteSpace: 'pre-wrap',
      wordBreak: 'keep-all',
    },
  }),
)
