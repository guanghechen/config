import { isEqual } from '@guanghechen/equal'
import cn from 'clsx'
import React from 'react'
import { Json } from '@/component/json'
import { PRESET_CLASSES } from '@/constant/classes'

interface IProps {
  readonly frontmatter: Record<string, unknown> | undefined
  readonly singleColumn: boolean
}

export class FrontmatterView extends React.Component<IProps> {
  public static displayName: string = 'MarkdownViewFrontmatterView'

  public override render(): React.ReactElement {
    const { frontmatter, singleColumn } = this.props
    return (
      <div
        className={cn(
          'flex-auto basis-0 border-4 border-transparent backdrop-blur-md backdrop-saturate-150 bg-white/70 rounded-lg shadow-lg text-slate-800 dark:bg-gray-800/60 dark:text-gray-200',
          {
            'overflow-auto h-full': !singleColumn,
            [PRESET_CLASSES.scrollbar]: !singleColumn,
            'flex justify-center': singleColumn,
          },
        )}
      >
        <div className="p-4">
          <h3 className="text-lg p-0 m-0 mb-4 font-medium text-gray-800 dark:text-gray-100">
            Frontmatter
          </h3>
          <Json json={frontmatter} initialCollapsed="expanded" />
        </div>
      </div>
    )
  }

  public override shouldComponentUpdate(nextProps: Readonly<IProps>): boolean {
    const props: IProps = this.props
    return (
      props.singleColumn !== nextProps.singleColumn ||
      !isEqual(props.frontmatter, nextProps.frontmatter)
    )
  }
}
