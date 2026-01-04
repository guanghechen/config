import equals from '@guanghechen/equal'
import type { Table } from '@yozora/ast'
import React from 'react'
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
  public static displayName = 'YozoraTable'

  public override render(): React.ReactElement {
    const { columns, children: rows } = this.props
    const aligns = columns.map(col => col.align ?? undefined)
    const [ths, ...tds] = rows.map(row =>
      row.children.map((cell, index) => <NodesRenderer key={index} nodes={cell.children} />),
    )
    return (
      <table className="yozora-table box-border overflow-auto w-full p-0 border-collapse rounded-lg border-spacing-0 border border-gray-200 dark:border-gray-700 mx-auto mb-5 leading-relaxed [font-variation-settings:_'opsz'_40,_'wght'_410] bg-white dark:bg-gray-850">
        <thead>
          <tr className="bg-gray-50 dark:bg-gray-800 border-b border-gray-200 dark:border-gray-700">
            {ths.map((children, index) => (
              <Th key={index} align={aligns[index]}>
                {children}
              </Th>
            ))}
          </tr>
        </thead>
        <tbody>
          {tds.map((row, rowIndex) => (
            <tr
              key={rowIndex}
              className="border-b border-gray-200 dark:border-gray-700 hover:bg-blue-50/50 dark:hover:bg-blue-900/20 transition-colors duration-150 last:border-b-0"
            >
              {row.map((children, index) => (
                <td
                  key={index}
                  align={aligns[index]}
                  className="p-3 border-r border-gray-200 dark:border-gray-700 last:border-r-0 bg-white dark:bg-gray-800"
                >
                  {children}
                </td>
              ))}
            </tr>
          ))}
        </tbody>
      </table>
    )
  }

  public override shouldComponentUpdate(nextProps: Readonly<Table>): boolean {
    const props = this.props
    return !equals(props.columns, nextProps.columns) || !equals(props.children, nextProps.children)
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

  public override render(): React.ReactElement {
    const { align, children } = this.props
    return (
      <th
        ref={this.ref}
        align={align}
        className="p-3 font-semibold text-gray-800 dark:text-gray-100 whitespace-nowrap overflow-hidden text-ellipsis border-r border-gray-200 dark:border-gray-700 last:border-r-0"
      >
        {children}
      </th>
    )
  }

  public override shouldComponentUpdate(nextProps: Readonly<IThProps>): boolean {
    const props = this.props
    return props.align !== nextProps.align || props.children !== nextProps.children
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
