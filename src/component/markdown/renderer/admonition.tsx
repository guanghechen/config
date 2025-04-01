import type { Admonition } from '@yozora/ast'
import cn from 'clsx'
import React from 'react'
import {
  AdmonitionCautionIcon,
  AdmonitionDangerIcon,
  AdmonitionHintIcon,
  AdmonitionInfoIcon,
  AdmonitionNoteIcon,
  AdmonitionTipIcon,
} from '@/component/icon/admonition'
import { NodesRenderer } from '../NodesRenderer'

interface IAdmonitionDescriptor {
  readonly type: string
  readonly icon: React.ReactElement
  readonly gradientClass: string
  readonly borderClass: string
  readonly textClass: string
  readonly bgClass: string
}

/**
 * Render `Admonition`.
 */
export class AdmonitionRenderer extends React.Component<Admonition> {
  public static displayName = 'YozoraAdmonition'

  public override render(): React.ReactElement {
    const { children: childNodes, title, keyword } = this.props
    const descriptor = getAdmonitionDescriptor(keyword)

    return (
      <div
        className={cn(
          'yozora-admonition',
          `yozora-admonition-${descriptor.type}`,
          'relative box-border rounded-lg mb-4 shadow-md overflow-hidden',
          'border-l-4 transition-all hover:shadow-lg dark:shadow-lg/20 dark:hover:shadow-xl/20',
          descriptor.borderClass,
        )}
      >
        <div
          className={cn('absolute inset-0 opacity-10 dark:opacity-20', descriptor.gradientClass)}
        />
        <div className={cn('flex items-center px-5 gap-2 pt-3 relative z-10', descriptor.bgClass)}>
          <span className={descriptor.textClass}>{descriptor.icon}</span>

          <span
            className={cn(
              `yozora-admonition__title yozora-admonition-${descriptor.type}__title font-medium text-base`,
              descriptor.textClass,
            )}
          >
            {title ? <NodesRenderer nodes={title} /> : descriptor.type}
          </span>
        </div>
        <div
          className={cn('yozora-admonition__content px-5 py-4 relative z-10', descriptor.bgClass)}
        >
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

function getAdmonitionDescriptor(keyword = 'note'): IAdmonitionDescriptor {
  const type = keyword.trim().toLowerCase()

  switch (type) {
    case 'danger':
    case 'error':
      return {
        type: 'danger',
        icon: <AdmonitionDangerIcon className="w-5 h-5" />,
        gradientClass: 'bg-gradient-to-br from-red-500 to-red-700',
        borderClass: 'border-red-500 dark:border-red-600',
        textClass: 'text-red-700 dark:text-red-300',
        bgClass: 'bg-red-50 dark:bg-red-900/30',
      }
    case 'caution':
    case 'warning':
      return {
        type: 'caution',
        icon: <AdmonitionCautionIcon className="w-5 h-5" />,
        gradientClass: 'bg-gradient-to-br from-amber-500 to-amber-700',
        borderClass: 'border-amber-500 dark:border-amber-600',
        textClass: 'text-amber-700 dark:text-amber-300',
        bgClass: 'bg-amber-50 dark:bg-amber-900/30',
      }
    case 'hint':
      return {
        type: 'hint',
        icon: <AdmonitionHintIcon className="w-5 h-5" />,
        gradientClass: 'bg-gradient-to-br from-purple-500 to-purple-700',
        borderClass: 'border-purple-500 dark:border-purple-600',
        textClass: 'text-purple-700 dark:text-purple-300',
        bgClass: 'bg-purple-50 dark:bg-purple-900/30',
      }
    case 'info':
    case 'important':
      return {
        type: 'info',
        icon: <AdmonitionInfoIcon className="w-5 h-5" />,
        gradientClass: 'bg-gradient-to-br from-blue-500 to-blue-700',
        borderClass: 'border-blue-500 dark:border-blue-600',
        textClass: 'text-blue-700 dark:text-blue-300',
        bgClass: 'bg-blue-50 dark:bg-blue-900/30',
      }
    case 'tip':
    case 'success':
      return {
        type: 'tip',
        icon: <AdmonitionTipIcon className="w-5 h-5" />,
        gradientClass: 'bg-gradient-to-br from-green-500 to-green-700',
        borderClass: 'border-green-500 dark:border-green-600',
        textClass: 'text-green-700 dark:text-green-300',
        bgClass: 'bg-green-50 dark:bg-green-900/30',
      }
    case 'note':
    case 'default':
    case '':
    default:
      return {
        type: 'note',
        icon: <AdmonitionNoteIcon className="w-5 h-5" />,
        gradientClass: 'bg-gradient-to-br from-gray-500 to-gray-700',
        borderClass: 'border-gray-500 dark:border-gray-600',
        textClass: 'text-gray-700 dark:text-gray-300',
        bgClass: 'bg-gray-50 dark:bg-gray-800/50',
      }
  }
}
