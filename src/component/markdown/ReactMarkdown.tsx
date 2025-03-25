import { css, cx } from '@emotion/css'
import type { Definition, FootnoteDefinition, Root } from '@yozora/ast'
import React from 'react'
import type { INodeRendererMap } from './context'
import { MarkdownProvider, astClasses, useMarkdownAst } from './context'
import { FootnoteDefinitions } from './FootnoteDefinitions'
import { NodesRenderer } from './NodesRenderer'

interface IProps {
  /**
   * Text content of markdown.
   */
  readonly ast: Root
  /**
   * Customized node renderer mpa.
   */
  readonly customizedRendererMap?: Readonly<Partial<INodeRendererMap>>
  /**
   * Preset Link / Image reference definitions.
   */
  readonly presetDefinitionMap?: Readonly<Record<string, Definition>>
  /**
   * Preset footnote reference definitions.
   */
  readonly presetFootnoteDefinitionMap?: Readonly<Record<string, FootnoteDefinition>>
  /**
   * Whether if show lineno for code block.
   */
  readonly showCodeLineno?: boolean
  /**
   * Root css class of the component.
   */
  readonly className?: string
  /**
   * Root css style.
   */
  readonly style?: React.CSSProperties
  /**
   * Markdown theme scheme.
   */
  readonly theme: string
}

export const ReactMarkdown: React.FC<IProps> = props => {
  const {
    customizedRendererMap,
    presetDefinitionMap,
    presetFootnoteDefinitionMap,
    showCodeLineno,
    ast,
    className,
    style,
    theme,
  } = props
  const cls: string = cx(rootCls, theme === 'darken' && astClasses.rootDarken, className)

  return (
    <div className={cls} style={style}>
      <MarkdownProvider
        ast={ast}
        customizedRendererMap={customizedRendererMap}
        presetDefinitionMap={presetDefinitionMap}
        presetFootnoteDefinitionMap={presetFootnoteDefinitionMap}
        showCodeLineno={showCodeLineno}
        theme={theme}
      >
        <ReactMarkdownInner />
      </MarkdownProvider>
    </div>
  )
}
ReactMarkdown.displayName = 'ReactMarkdown'

const ReactMarkdownInner: React.FC = () => {
  const ast = useMarkdownAst()
  return (
    <section>
      <main>
        <NodesRenderer nodes={ast.children} />
      </main>
      <footer>
        <FootnoteDefinitions dontNeedFootnoteDefinitions={false} />
      </footer>
    </section>
  )
}

const rootCls = cx(
  astClasses.root,
  css({
    wordBreak: 'break-all',
    userSelect: 'unset',
    fontFamily: "'Maple Mono NF CN', 'Roboto Mono', monospace, sans-serif",
    [astClasses.listItem]: {
      [`> ${astClasses.list}`]: {
        marginLeft: '1.2em',
      },
    },
    '> :last-child': {
      marginBottom: 0,
    },
  }),
)
