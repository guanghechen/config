import React from 'react'
import { CopyButton } from '@/component/CopyButton'

interface IProps {
  readonly filepath: string | null
  readonly extname: string
}

export class Composer extends React.PureComponent<IProps> {
  public static readonly displayName = 'UnknownViewComposer'

  public override render(): React.ReactElement {
    const { filepath, extname } = this.props
    return (
      <div className="flex h-full w-full flex-col items-center justify-center">
        <div className="rounded-lg bg-gray-50 p-8 shadow-md dark:bg-gray-800">
          <div className="mb-4 flex justify-center">
            <svg
              xmlns="http://www.w3.org/2000/svg"
              className="h-16 w-16 text-gray-400 dark:text-gray-500"
              fill="none"
              viewBox="0 0 24 24"
              stroke="currentColor"
            >
              <path
                strokeLinecap="round"
                strokeLinejoin="round"
                strokeWidth={1.5}
                d="M9.172 16.172a4 4 0 015.656 0M9 10h.01M15 10h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"
              />
            </svg>
          </div>
          <h3 className="mb-2 text-center text-lg font-medium text-gray-700 dark:text-gray-300">
            Unsupported File Type
          </h3>
          <p className="mb-3 text-center text-gray-600 dark:text-gray-400">
            The file extension <span className="font-mono font-medium">{extname || '(none)'}</span>{' '}
            is not currently supported.
          </p>
          {!!filepath && (
            <div className="mt-4 overflow-hidden rounded-md border border-gray-200 bg-gray-50 px-3 py-2.5 dark:border-gray-700 dark:bg-gray-800/70">
              <div className="flex items-center justify-between gap-3">
                <div className="overflow-hidden">
                  <p className="truncate font-mono text-sm font-medium text-gray-600 dark:text-gray-300">
                    {filepath}
                  </p>
                </div>
                <CopyButton
                  className="flex-shrink-0 text-gray-500 hover:text-gray-700 dark:text-gray-400 dark:hover:text-gray-200"
                  calcContentForCopy={() => filepath}
                />
              </div>
            </div>
          )}
        </div>
      </div>
    )
  }
}
