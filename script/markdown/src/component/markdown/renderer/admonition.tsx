import { css } from '@emotion/css'
import { ParagraphType } from '@yozora/ast'
import type { Admonition, Paragraph } from '@yozora/ast'
import cn from 'clsx'
import React from 'react'
import { astClasses } from '../context'
import { NodesRenderer } from '../NodesRenderer'

/**
 * Render `Admonition`.
 */
export class AdmonitionRenderer extends React.Component<Admonition> {
  public override shouldComponentUpdate(nextProps: Readonly<Admonition>): boolean {
    const props = this.props
    return props.children !== nextProps.children
  }

  public override render(): React.ReactElement {
    const { children: childNodes, keyword } = this.props

    if (keyword === 'contextList') {
      if (childNodes.length === 1 && childNodes[0].type === ParagraphType) {
        const paragraph = childNodes[0] as Paragraph
        return (
          <div className={cn(astClasses.admonition, classes.contextList)}>
            <div key="content" className={classes.contextListContent}>
              <NodesRenderer nodes={paragraph.children.slice(1)} />
            </div>
            <div key="image" className={classes.contextListImage}>
              <NodesRenderer nodes={paragraph.children.slice(0, 1)} />
            </div>
          </div>
        )
      }

      return (
        <div className={cn(astClasses.admonition, classes.contextList)}>
          <div key="content" className={classes.contextListContent}>
            <NodesRenderer nodes={childNodes.slice(1)} />
          </div>
          <div key="image" className={classes.contextListImage}>
            <NodesRenderer nodes={childNodes.slice(0, 1)} />
          </div>
        </div>
      )
    }

    return (
      <div className={cn(astClasses.admonition, classes.fallback)}>
        <NodesRenderer nodes={childNodes} />
      </div>
    )
  }
}

const classes = {
  contextList: css({
    display: 'flex',
    width: '100%',
    marginTop: '1rem',
    marginBottom: '1rem',
    paddingBottom: '1rem',
    gap: '1.5rem',
    borderBottom: '1px solid #e0e0e0',
    fontSize: '0.875rem',
  }),
  contextListContent: css({
    flexGrow: 1,
    lineHeight: 1.5,
  }),
  contextListImage: css({
    marginTop: '0.5rem',
    display: 'flex',
    width: '6rem',
    flexShrink: 0,
  }),
  fallback: css({
    boxSizing: 'border-box',
    padding: '0.625em 1em',
    borderLeft: '0.25em solid var(--colorBorderBlockquote)',
    margin: '0px 0px 1.25em 0px',
    background: 'var(--colorBgBlockquote)',
    boxShadow: '0 1px 2px 0 hsla(0deg, 0%, 0%, 0.1)',
    '> :last-child': {
      marginBottom: 0,
    },
  }),
}
