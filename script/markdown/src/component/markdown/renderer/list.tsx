import { css, cx } from '@emotion/css';
import type { List } from '@yozora/ast';
import React from 'react';
import { astClasses } from '../context';
import { NodesRenderer } from '../NodesRenderer';

/**
 * Render `list`.
 *
 * @see https://www.npmjs.com/package/@yozora/ast#list
 * @see https://www.npmjs.com/package/@yozora/tokenizer-list
 */
export class ListRenderer extends React.Component<List> {
  public override shouldComponentUpdate(
    nextProps: Readonly<List>,
  ): boolean {
    const props = this.props;
    return (
      props.ordered !== nextProps.ordered ||
      props.orderType !== nextProps.orderType ||
      props.start !== nextProps.start ||
      props.children !== nextProps.children
    );
  }

  public override render(): React.ReactElement {
    const { ordered, orderType, start, children } = this.props;

    if (ordered) {
      return (
        <ol className={olCls} type={orderType} start={start}>
          <NodesRenderer nodes={children} />
        </ol>
      );
    }

    return (
      <ul className={ulCls}>
        <NodesRenderer nodes={children} />
      </ul>
    );
  }
}

const ulCls = cx(
  astClasses.list,
  'list-outside',
  'list-disc',
  css({
    padding: '0px',
    margin: '0 0 1em 2em',
    lineHeight: '2',
    '> :last-child': {
      marginBottom: '0px',
    },
    ul: {
      listStyleType: 'circle',
    },
    'ul ul': {
      listStyleType: 'square',
    },
  }),
);

const olCls = cx(
  astClasses.list,
  'list-outside',
  'list-decimal',
  css({
    padding: '0px',
    margin: '0 0 1em 2em',
    lineHeight: '2',
    '> :last-child': {
      marginBottom: '0px',
    },
    ol: {
      listStyleType: 'lower-alpha',
    },
    'ol ol': {
      listStyleType: 'roman',
    },
  }),
);
