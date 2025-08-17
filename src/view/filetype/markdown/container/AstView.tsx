import type { Root } from '@yozora/ast'
import cn from 'clsx'
import React from 'react'
import { Json } from '@/component/json'
import { PRESET_CLASSES } from '@/shared/constant'

interface IProps {
  readonly ast: Root
  readonly singleColumn: boolean
}

export class AstView extends React.Component<IProps> {
  public static displayName: string = 'MarkdownViewAstView'

  public override render(): React.ReactElement {
    const { ast, singleColumn } = this.props
    return (
      <div
        className={cn(
          'w-[48rem] flex-initial border-x-4 border-y-20 border-transparent backdrop-blur-md backdrop-saturate-150 bg-white/70 rounded-lg shadow-lg text-slate-800 dark:bg-gray-800/60 dark:text-gray-200',
          {
            'overflow-auto h-full': !singleColumn,
            [PRESET_CLASSES.scrollbar]: !singleColumn,
          },
        )}
      >
        <div className="px-8 py-4">
          <Json json={ast} />
        </div>
      </div>
    )
  }

  public override shouldComponentUpdate(nextProps: Readonly<IProps>): boolean {
    const props: IProps = this.props
    return props.singleColumn !== nextProps.singleColumn || props.ast !== nextProps.ast
  }
}
