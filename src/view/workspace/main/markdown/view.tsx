import { isEqual } from '@guanghechen/equal'
import type { Root } from '@yozora/ast'
import type { IHeadingToc } from '@yozora/ast-util'
import cn from 'clsx'
import React from 'react'
import { Json } from '@/component/json'
import { MarkdownToc, ReactMarkdown } from '@/component/markdown'
import { ReactMarkdownContent } from '@/component/markdown/ReactMarkdownContent'
import { PRESET_CLASSES } from '@/constant/classes'

interface IMainContentProps {
  readonly containerRef: React.RefObject<HTMLDivElement | null>
  readonly filepath: string | null
  readonly frontmatter: Record<string, unknown> | undefined
  readonly singleColumn: boolean
}

export class ContentView extends React.Component<IMainContentProps> {
  public static displayName: string = 'ContentView'

  public override render(): React.ReactElement {
    const { containerRef, filepath, frontmatter, singleColumn } = this.props
    return (
      <div
        ref={containerRef}
        className={cn('w-[72rem] flex-initial px-2', {
          'overflow-auto h-full': !singleColumn,
          [PRESET_CLASSES.scrollbar]: !singleColumn,
        })}
      >
        <ReactMarkdownContent
          Tag="h1"
          className="mb-4 flex justify-center text-3xl font-bold text-gray-900 dark:text-white"
          content={(frontmatter?.title as string) || filepath || 'Untitled'}
        />
        <ReactMarkdown />
      </div>
    )
  }

  public override shouldComponentUpdate(nextProps: Readonly<IMainContentProps>): boolean {
    const props: IMainContentProps = this.props
    return (
      props.containerRef !== nextProps.containerRef ||
      props.singleColumn !== nextProps.singleColumn ||
      props.filepath !== nextProps.filepath ||
      !isEqual(props.frontmatter, nextProps.frontmatter)
    )
  }
}

interface IAstViewProps {
  readonly ast: Root
  readonly singleColumn: boolean
}

export class AstView extends React.Component<IAstViewProps> {
  public static displayName: string = 'AstView'

  public override render(): React.ReactElement {
    const { ast, singleColumn } = this.props
    return (
      <div
        className={cn('w-[48rem] flex-initial px-2', {
          'overflow-auto h-full': !singleColumn,
          [PRESET_CLASSES.scrollbar]: !singleColumn,
        })}
      >
        <Json json={ast} />
      </div>
    )
  }

  public override shouldComponentUpdate(nextProps: Readonly<IAstViewProps>): boolean {
    const props: IAstViewProps = this.props
    return props.singleColumn !== nextProps.singleColumn || props.ast !== nextProps.ast
  }
}

interface ITocViewProps {
  readonly singleColumn: boolean
  readonly toc: IHeadingToc | undefined
  readonly tocActivatedIdentifier: string | null
  readonly setAactivatedIdentifier: (identifier: string | null) => void
}

export class TocView extends React.Component<ITocViewProps> {
  public static displayName: string = 'TocView'

  public override render(): React.ReactElement {
    const { singleColumn, toc, tocActivatedIdentifier, setAactivatedIdentifier } = this.props
    return (
      <div
        className={cn('flex-auto basis-0 px-2', {
          'overflow-auto h-full': !singleColumn,
          [PRESET_CLASSES.scrollbar]: !singleColumn,
          'flex justify-center': singleColumn,
        })}
      >
        <h3 className="mb-4 text-lg font-medium text-gray-800 dark:text-gray-100">
          Table of Contents
        </h3>
        <div>
          <MarkdownToc
            toc={toc}
            activatedIdentifier={tocActivatedIdentifier}
            setAactivatedIdentifier={setAactivatedIdentifier}
          />
        </div>
      </div>
    )
  }

  public override shouldComponentUpdate(nextProps: Readonly<ITocViewProps>): boolean {
    const props: ITocViewProps = this.props
    return (
      props.singleColumn !== nextProps.singleColumn ||
      props.tocActivatedIdentifier !== nextProps.tocActivatedIdentifier ||
      props.setAactivatedIdentifier !== nextProps.setAactivatedIdentifier ||
      !isEqual(props.toc, nextProps.toc)
    )
  }
}

interface IFrontmatterViewProps {
  readonly frontmatter: Record<string, unknown> | undefined
  readonly singleColumn: boolean
}

export class FrontmatterView extends React.Component<IFrontmatterViewProps> {
  public static displayName: string = 'FrontmatterView'

  public override render(): React.ReactElement {
    const { frontmatter, singleColumn } = this.props
    return (
      <div
        className={cn('flex-auto basis-0 px-2', {
          'overflow-auto h-full': !singleColumn,
          [PRESET_CLASSES.scrollbar]: !singleColumn,
          'flex justify-center': singleColumn,
        })}
      >
        <h3 className="mb-4 text-lg font-medium text-gray-800 dark:text-gray-100">Frontmatter</h3>
        <Json json={frontmatter} initialCollapsed="expanded" />
      </div>
    )
  }

  public override shouldComponentUpdate(nextProps: Readonly<IFrontmatterViewProps>): boolean {
    const props: IFrontmatterViewProps = this.props
    return (
      props.singleColumn !== nextProps.singleColumn ||
      !isEqual(props.frontmatter, nextProps.frontmatter)
    )
  }
}
