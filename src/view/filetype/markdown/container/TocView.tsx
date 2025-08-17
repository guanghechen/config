import { isEqual } from '@guanghechen/equal'
import type { IHeadingToc } from '@yozora/ast-util'
import cn from 'clsx'
import React from 'react'
import { MarkdownToc } from '@/component/markdown'
import { PRESET_CLASSES } from '@/shared/constant/classes'

interface IProps {
  readonly singleColumn: boolean
  readonly toc: IHeadingToc | undefined
  readonly tocActivatedIdentifier: string | null
  readonly setActivatedIdentifier: (identifier: string | null) => void
}

export class TocView extends React.Component<IProps> {
  public static displayName: string = 'MarkdownViewTocView'

  public override render(): React.ReactElement {
    const { singleColumn, toc, tocActivatedIdentifier, setActivatedIdentifier } = this.props
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
            Table of Contents
          </h3>
          <div>
            <MarkdownToc
              toc={toc}
              activatedIdentifier={tocActivatedIdentifier}
              setActivatedIdentifier={setActivatedIdentifier}
            />
          </div>
        </div>
      </div>
    )
  }

  public override shouldComponentUpdate(nextProps: Readonly<IProps>): boolean {
    const props: IProps = this.props
    return (
      props.singleColumn !== nextProps.singleColumn ||
      props.tocActivatedIdentifier !== nextProps.tocActivatedIdentifier ||
      props.setActivatedIdentifier !== nextProps.setActivatedIdentifier ||
      !isEqual(props.toc, nextProps.toc)
    )
  }
}
