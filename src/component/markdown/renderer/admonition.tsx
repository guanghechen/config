import type { Admonition } from '@yozora/ast'
import cn from 'clsx'
import React from 'react'
import { astClasses } from '../context'
import { getAdmonitionDescriptor } from './descriptor'
import { NodesRenderer } from '../NodesRenderer'

/**
 * Render `Admonition`.
 */
export class AdmonitionRenderer extends React.Component<Admonition> {
  public static displayName = 'YozoraAdmonition'

  public override render(): React.ReactElement {
    const { children: childNodes, keyword } = this.props

    // Handle contextList keyword special case separately
    if (keyword === 'contextList') {
      return (
        <div
          className={cn(
            astClasses.admonition,
            'flex w-full my-4 pb-4 gap-6 border-b border-gray-200 text-sm',
          )}
        >
          <div className="flex-grow leading-relaxed">
            <NodesRenderer nodes={childNodes.slice(1)} />
          </div>
          <div className="mt-2 flex w-24 flex-shrink-0">
            <NodesRenderer nodes={childNodes.slice(0, 1)} />
          </div>
        </div>
      )
    }

    // Handle different admonition types (note, info, tip, caution, danger, hint)
    const descriptor = getAdmonitionDescriptor(keyword)

    return (
      <div
        className={cn(
          astClasses.admonition,
          'box-border rounded-md mb-5 shadow-sm [&>:last-child]:mb-0',
          descriptor.bgClass,
        )}
      >
        <div className={cn('flex items-center px-4 py-2 border-b', descriptor.borderClass)}>
          <span className={cn('mr-2', descriptor.textClass)}>{descriptor.icon}</span>
          <span className={cn('font-semibold text-sm tracking-wider', descriptor.textClass)}>
            {descriptor.title}
          </span>
        </div>
        <div className="px-4 py-3">
          <NodesRenderer nodes={childNodes} />
        </div>
      </div>
    )
  }

  public override shouldComponentUpdate(nextProps: Readonly<Admonition>): boolean {
    const props = this.props
    return props.children !== nextProps.children || props.keyword !== nextProps.keyword
  }
}
