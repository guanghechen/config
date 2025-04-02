import { isEqual } from '@guanghechen/equal'
import cn from 'clsx'
import React from 'react'

interface IProps {
  readonly countOfLines: number
  readonly highlightLinenos: number[] | undefined
}

export class HighlightLinenos extends React.Component<IProps> {
  public static readonly displayName = 'CodeHighlightLinenos'

  public override render(): React.ReactElement {
    const { countOfLines, highlightLinenos = [] } = this.props
    const lines: React.ReactElement[] = []
    for (let lineno = 0; lineno < countOfLines; ++lineno) {
      const isHighlight = highlightLinenos.includes(lineno + 1)
      const line = (
        <div
          key={lineno}
          className={cn(
            'box-border flex min-w-fit w-full px-1.5 text-sm leading-6 h-6',
            'justify-end px-1',
            isHighlight && 'bg-amber-500/30 dark:bg-amber-600/30 border-transparent',
          )}
        >
          <span key={lineno}>{lineno + 1}</span>
        </div>
      )
      lines.push(line)
    }
    return <React.Fragment>{lines}</React.Fragment>
  }

  public override shouldComponentUpdate(nextProps: Readonly<IProps>): boolean {
    const props = this.props
    return (
      props.countOfLines !== nextProps.countOfLines ||
      !isEqual(props.highlightLinenos, nextProps.highlightLinenos)
    )
  }
}
