import { css, cx } from '@emotion/css'
import type { Heading } from '@yozora/ast'
import React from 'react'
import { astClasses } from '../context'
import { NodesRenderer } from '../NodesRenderer'

type IHeading = 'h1' | 'h2' | 'h3' | 'h4' | 'h5' | 'h6'

/**
 * Render `heading` content.
 *
 * @see https://www.npmjs.com/package/@yozora/ast#heading
 * @see https://www.npmjs.com/package/@yozora/tokenizer-heading
 */
export class HeadingRenderer extends React.Component<Heading> {
  public static displayName = 'YozoraHeading'

  public override render(): React.ReactElement {
    const { depth, identifier, children } = this.props

    const id = identifier == null ? undefined : encodeURIComponent(identifier)
    const h: IHeading = ('h' + depth) as IHeading
    const H: any = h
    const cls = cx(astClasses.heading, classes.heading, classes[h])

    return (
      <H id={id} className={cls}>
        {identifier && (
          <a className={classes.anchor} href={'#' + id} aria-hidden="true">
            <svg viewBox="0 0 16 16" version="1.1" width="16" height="16" aria-hidden="true">
              <path
                fillRule="evenodd"
                d="M7.775 3.275a.75.75 0 001.06 1.06l1.25-1.25a2 2 0 112.83 2.83l-2.5 2.5a2 2 0 01-2.83 0 .75.75 0 00-1.06 1.06 3.5 3.5 0 004.95 0l2.5-2.5a3.5 3.5 0 00-4.95-4.95l-1.25 1.25zm-4.69 9.64a2 2 0 010-2.83l2.5-2.5a2 2 0 012.83 0 .75.75 0 001.06-1.06 3.5 3.5 0 00-4.95 0l-2.5 2.5a3.5 3.5 0 004.95 4.95l1.25-1.25a.75.75 0 00-1.06-1.06l-1.25 1.25a2 2 0 01-2.83 0z"
              />
            </svg>
          </a>
        )}
        <p className={classes.content}>
          <NodesRenderer nodes={children} />
        </p>
      </H>
    )
  }

  public override shouldComponentUpdate(nextProps: Readonly<Heading>): boolean {
    const props = this.props
    return (
      props.depth !== nextProps.depth ||
      props.identifier !== nextProps.identifier ||
      props.children !== nextProps.children
    )
  }
}

const anchorCls = css({
  position: 'absolute',
  left: '-2rem',
  flex: '0 0 3rem',
  paddingLeft: '0.5rem',
  color: 'var(--colorLink)',
  opacity: 0,
  transition: 'color 0.2s ease-in-out, opacity 0.2s ease-in-out',
  userSelect: 'none',
  textDecoration: 'none',
  '> svg': {
    overflow: 'hidden',
    display: 'inline-block',
    verticalAlign: 'middle',
    fill: 'currentColor',
  },
})

const classes = {
  heading: css({
    position: 'relative',
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'flex-start',
    padding: '0px',
    margin: '0px 0px 1.25em 0px',
    marginBottom: '1em',
    lineHeight: '1.25',
    fontFamily: 'var(--fontFamilyHeading)',
    color: 'var(--colorHeading)',
    [`&:active .${anchorCls}`]: {
      opacity: 0.8,
      color: 'var(--colorLinkActive)',
    },
    [`&&:hover .${anchorCls}`]: {
      opacity: 0.8,
      color: 'var(--colorLinkHover)',
    },
  }),
  anchor: anchorCls,
  content: css({
    flex: '0 1 auto',
    minWidth: 0,
    margin: 0,
    overflow: 'hidden',
    textOverflow: 'ellipsis',
    whiteSpace: 'pre-wrap',
    lineHeight: '1.7',
  }),
  h1: css({
    padding: '0.3rem 0',
    borderBottom: '1px solid var(--colorBorderHeading)',
    fontSize: '2rem',
    fontStyle: 'normal',
    fontWeight: 500,
  }),
  h2: css({
    padding: '0.3rem 0',
    borderBottom: '1px solid var(--colorBorderHeading)',
    fontSize: '1.5rem',
    fontStyle: 'normal',
    fontWeight: 500,
    marginBottom: '0.875rem',
  }),
  h3: css({
    fontSize: '1.25rem',
    fontStyle: 'normal',
    fontWeight: 500,
  }),
  h4: css({
    fontSize: '1rem',
    fontStyle: 'normal',
    fontWeight: 500,
  }),
  h5: css({
    fontSize: '0.875rem',
    fontStyle: 'normal',
    fontWeight: 500,
  }),
  h6: css({
    fontSize: '0.85rem',
    fontStyle: 'normal',
    fontWeight: 500,
  }),
}
