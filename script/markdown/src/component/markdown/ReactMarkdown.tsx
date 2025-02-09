import { css, cx } from '@emotion/css'
import { useDeepCompareEffect, useDeepCompareMemo } from '@guanghechen/react-hooks'
import { useComputed } from '@guanghechen/react-viewmodel'
import type { Definition, Root } from '@yozora/ast'
import React from 'react'
import type { INodeRendererContext, INodeRendererMap } from './context'
import {
  MarkdownViewModel,
  NodeRendererContextType,
  astClasses,
  useNodeRendererContext,
} from './context'
import { NodesRenderer } from './NodesRenderer'
import { buildNodeRendererMap } from './renderer'

export interface IMarkdownProps {
  /**
   * The markdown file path.
   */
  readonly filepath: string
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
   * Whether if show lineno for code block.
   */
  readonly showCodeLineno?: boolean
  /**
   * Custom behavior instead of opening the link in a new tab.
   */
  readonly onClickAnchor?: React.MouseEventHandler<HTMLAnchorElement>
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

export const ReactMarkdown: React.FC<IMarkdownProps> = props => {
  const {
    onClickAnchor,
    customizedRendererMap,
    showCodeLineno = true,
    filepath,
    ast: astFromProps,
    className,
    style,
    theme: themeScheme,
  } = props

  const presetDefinitionMap: Record<string, Readonly<Definition>> = useDeepCompareMemo(
    () => props.presetDefinitionMap ?? {},
    [props.presetDefinitionMap],
  )
  const [viewmodel] = React.useState<MarkdownViewModel>(() => {
    return new MarkdownViewModel({
      filepath,
      ast: astFromProps,
      rendererMap: buildNodeRendererMap(customizedRendererMap),
      presetDefinitionMap,
      showCodeLineno,
      themeScheme,
    })
  })

  const context = React.useMemo<INodeRendererContext>(
    () => ({ viewmodel, onClickAnchor }),
    [viewmodel, onClickAnchor],
  )

  const cls: string = cx(rootCls, themeScheme === 'darken' && astClasses.rootDarken, className)

  useDeepCompareEffect(() => {
    viewmodel.setContent(filepath, astFromProps)
  }, [viewmodel, filepath, astFromProps])

  React.useEffect(() => {
    viewmodel.showCodeLineno$.next(showCodeLineno)
  }, [viewmodel, showCodeLineno])

  React.useEffect(() => {
    viewmodel.themeScheme$.next(themeScheme)
  }, [viewmodel, themeScheme])

  return (
    <div className={cls} style={style}>
      <NodeRendererContextType.Provider value={context}>
        <ReactMarkdownInner />
      </NodeRendererContextType.Provider>
    </div>
  )
}

const ReactMarkdownInner: React.FC = () => {
  const { viewmodel } = useNodeRendererContext()
  const ast: Root = useComputed(viewmodel.ast$)
  return <NodesRenderer nodes={ast.children} />
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
