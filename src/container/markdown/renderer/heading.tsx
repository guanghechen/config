import type { Heading } from '@yozora/ast'
import cn from 'clsx'
import React from 'react'
import { NodesRenderer } from '../NodesRenderer'

type IHeading = 'h1' | 'h2' | 'h3' | 'h4' | 'h5' | 'h6'

const levelClasses: Record<IHeading, string> = {
  h1: 'py-3 mt-2 border-b border-b-gray-200 dark:border-b-gray-600 text-3xl font-bold bg-gradient-to-br from-gray-900 to-gray-700 dark:from-gray-100 dark:to-gray-300 bg-clip-text text-transparent',
  h2: 'py-2 mt-6 mb-4 border-b border-b-gray-200 dark:border-b-gray-600 text-2xl font-semibold text-gray-800 dark:text-gray-200',
  h3: 'mt-5 mb-3 text-xl font-medium text-gray-700 dark:text-gray-300',
  h4: 'mt-4 mb-2 text-lg font-medium text-gray-700 dark:text-gray-300',
  h5: 'mt-3 mb-1 text-base font-medium text-gray-600 dark:text-gray-400',
  h6: 'mt-2 mb-1 text-sm font-medium text-gray-500 dark:text-gray-500 uppercase tracking-wider',
}

/**
 * Render `heading` content.
 *
 * @see https://www.npmjs.com/package/@yozora/ast#heading
 * @see https://www.npmjs.com/package/@yozora/tokenizer-heading
 */
export class HeadingRenderer extends React.Component<Heading> {
  public static displayName = 'YozoraHeading'

  public override render(): React.ReactElement {
    const { depth, identifier, children } = this.props

    const id = identifier == null ? undefined : encodeURIComponent(identifier)
    const h: IHeading = ('h' + depth) as IHeading
    const H: any = h

    return (
      <H
        id={id}
        className={cn(
          'yozora-heading relative flex items-center justify-start p-0 leading-tight font-heading group',
          levelClasses[h],
        )}
      >
        {identifier && (
          <a
            className="absolute -left-8 flex-[0_0_3rem] pl-2 text-sky-500 opacity-0 transition-[color,opacity] duration-200 ease-in-out select-none no-underline group-hover:opacity-80 group-hover:text-sky-600 group-active:opacity-80 group-active:text-sky-700 dark:text-sky-400 dark:group-hover:text-sky-300 dark:group-active:text-sky-200"
            href={'#' + id}
            aria-hidden="true"
          >
            <svg
              viewBox="0 0 16 16"
              version="1.1"
              width="16"
              height="16"
              aria-hidden="true"
              className="overflow-hidden inline-block align-middle fill-current"
            >
              <path
                fillRule="evenodd"
                d="M7.775 3.275a.75.75 0 001.06 1.06l1.25-1.25a2 2 0 112.83 2.83l-2.5 2.5a2 2 0 01-2.83 0 .75.75 0 00-1.06 1.06 3.5 3.5 0 004.95 0l2.5-2.5a3.5 3.5 0 00-4.95-4.95l-1.25 1.25zm-4.69 9.64a2 2 0 010-2.83l2.5-2.5a2 2 0 012.83 0 .75.75 0 001.06-1.06 3.5 3.5 0 00-4.95 0l-2.5 2.5a3.5 3.5 0 004.95 4.95l1.25-1.25a.75.75 0 00-1.06-1.06l-1.25 1.25a2 2 0 01-2.83 0z"
              />
            </svg>
          </a>
        )}
        <p className="flex-[0_1_auto] min-w-0 m-0 overflow-hidden text-ellipsis whitespace-pre-wrap leading-7">
          <NodesRenderer nodes={children} />
        </p>
      </H>
    )
  }

  public override shouldComponentUpdate(nextProps: Readonly<Heading>): boolean {
    const props = this.props
    return (
      props.depth !== nextProps.depth ||
      props.identifier !== nextProps.identifier ||
      props.children !== nextProps.children
    )
  }
}
