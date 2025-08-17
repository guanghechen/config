import { isEqual } from '@guanghechen/equal'
import type { Heading, Root } from '@yozora/ast'
import cn from 'clsx'
import React from 'react'
import { NodesRenderer, ReactMarkdown } from '@/component/markdown'
import { ReactMarkdownContent } from '@/component/markdown/ReactMarkdownContent'
import { PRESET_CLASSES } from '@/shared/constant/classes'

interface IProps {
  readonly containerRef: React.RefObject<HTMLDivElement | null>
  readonly ast: Root
  readonly filepath: string | null
  readonly frontmatter: Record<string, unknown> | undefined
  readonly singleColumn: boolean
}

export class ContentView extends React.Component<IProps> {
  public static displayName: string = 'MarkdownViewContentView'

  public override render(): React.ReactElement {
    const { containerRef, ast, filepath, frontmatter, singleColumn } = this.props
    let title: React.ReactElement

    if (
      !frontmatter?.title &&
      ast.children[0].type === 'heading' &&
      (ast.children[0] as Heading).depth === 1
    ) {
      const heading: Heading = ast.children[0] as Heading
      title = (
        <h1 className="yozora-root">
          <NodesRenderer nodes={heading.children} />
        </h1>
      )
    } else {
      title = (
        <ReactMarkdownContent
          Tag="h1"
          content={(frontmatter?.title as string) || filepath || 'Untitled'}
        />
      )
    }

    return (
      <div
        ref={containerRef}
        className={cn(
          'w-[72rem] flex-initial border-x-4 border-y-20 border-transparent backdrop-blur-md backdrop-saturate-150 bg-white/70 rounded-lg shadow-lg text-slate-800 dark:bg-gray-800/60 dark:text-gray-200',
          {
            'overflow-auto h-full': !singleColumn,
            [PRESET_CLASSES.scrollbar]: !singleColumn,
          },
        )}
      >
        <div className="px-8 py-4">
          <div className="mb-4 flex justify-center text-3xl font-bold text-gray-900 dark:text-white">
            {title}
          </div>
          <ReactMarkdown ast={ast} dontShowFirstHeading={true} />
        </div>
      </div>
    )
  }

  public override shouldComponentUpdate(nextProps: Readonly<IProps>): boolean {
    const props: IProps = this.props
    return (
      props.ast !== nextProps.ast ||
      props.containerRef !== nextProps.containerRef ||
      props.singleColumn !== nextProps.singleColumn ||
      props.filepath !== nextProps.filepath ||
      !isEqual(props.frontmatter, nextProps.frontmatter)
    )
  }
}
