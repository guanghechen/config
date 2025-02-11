import { css, cx } from '@emotion/css'
import equals from '@guanghechen/equal'
import type { Table } from '@yozora/ast'
import React from 'react'
import { astClasses } from '../context'
import { NodesRenderer } from '../NodesRenderer'

/**
 * Render yozora `table`, `tableRow` and `tableCell`.
 *
 * @see https://www.npmjs.com/package/@yozora/ast#table
 * @see https://www.npmjs.com/package/@yozora/ast#tablecell
 * @see https://www.npmjs.com/package/@yozora/ast#tablerow
 * @see https://www.npmjs.com/package/@yozora/tokenizer-table
 * @see https://www.npmjs.com/package/@yozora/tokenizer-table-row
 * @see https://www.npmjs.com/package/@yozora/tokenizer-table-cell
 */
export class TableRenderer extends React.Component<Table> {
  public override shouldComponentUpdate(nextProps: Readonly<Table>): boolean {
    const props = this.props
    return !equals(props.columns, nextProps.columns) || !equals(props.children, nextProps.children)
  }

  public override render(): React.ReactElement {
    const { columns, children: rows } = this.props
    const aligns = columns.map(col => col.align ?? undefined)
    const [ths, ...tds] = rows.map(row =>
      row.children.map((cell, index) => <NodesRenderer key={index} nodes={cell.children} />),
    )
    return (
      <table className={cls}>
        <thead>
          <tr>
            {ths.map((children, index) => (
              <Th key={index} align={aligns[index]}>
                {children}
              </Th>
            ))}
          </tr>
        </thead>
        <tbody>
          {tds.map((row, rowIndex) => (
            <tr key={rowIndex}>
              {row.map((children, index) => (
                <td key={index} align={aligns[index]}>
                  {children}
                </td>
              ))}
            </tr>
          ))}
        </tbody>
      </table>
    )
  }
}

interface IThProps {
  align: 'left' | 'center' | 'right' | undefined
  children: React.ReactNode
}

class Th extends React.Component<IThProps> {
  protected readonly ref: React.RefObject<HTMLTableCellElement | null>

  constructor(props: IThProps) {
    super(props)
    this.ref = { current: null }
  }

  public override shouldComponentUpdate(nextProps: Readonly<IThProps>): boolean {
    const props = this.props
    return props.align !== nextProps.align || props.children !== nextProps.children
  }

  public override render(): React.ReactElement {
    const { align, children } = this.props
    return (
      <th ref={this.ref} align={align}>
        {children}
      </th>
    )
  }

  public override componentDidMount(): void {
    const th = this.ref.current
    if (th && th.textContent) {
      th.setAttribute('title', th.textContent)
    }
  }

  public override componentDidUpdate(): void {
    const th = this.ref.current
    if (th && th.textContent) {
      th.setAttribute('title', th.textContent)
    }
  }
}

const cls: string = cx(
  astClasses.table,
  css({
    boxSizing: 'border-box',
    overflow: 'auto',
    width: '100%',
    padding: 0,
    borderCollapse: 'collapse',
    borderRadius: '6px',
    borderSpacing: '0px',
    border: '1px solid var(--colorBorderTable)',
    margin: '0 auto 1.25em',
    lineHeight: '1.6',
    fontVariationSettings: '"opsz" 40, "wght" 410',
    '> thead': {
      tr: {
        borderBottom: '1px solid var(--colorBorderTable)',
        backgroundColor: 'var(--colorBgTableHead)',
      },
      th: {
        padding: '.625rem 1rem',
        borderLeft: '1px solid var(--colorBorderTable)',
        wordBreak: 'break-all',
        whiteSpace: 'wrap',
        overflow: 'hidden',
        textOverflow: 'ellipsis',
        '&:last-child': {
          borderRight: 'none',
        },
      },
    },
    '> tbody': {
      tr: {
        borderBottom: '1px solid var(--colorBorderTable)',
        background: 'var(--colorBgTableEvenRow)',
        '&:last-child': {
          borderBottom: 'none',
        },
      },
      td: {
        padding: '.625rem 1rem',
        borderRight: '1px solid var(--colorBorderTable)',
        '&:last-child': {
          borderRight: 'none',
        },
      },
    },
  }),
)
