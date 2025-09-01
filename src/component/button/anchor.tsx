import cn from 'clsx'
import React from 'react'
import { ApiRoutePathEnum } from '@/shared/constant/api'

interface IProps {
  readonly workspace: string | null
  readonly filepath: string | null
}

export class AnchorButton extends React.PureComponent<IProps> {
  public static readonly displayName: string = 'AnchorButton'

  public override render(): React.ReactElement {
    const { workspace, filepath } = this.props

    if (!filepath) {
      return <React.Fragment />
    }

    const url = workspace
      ? `${ApiRoutePathEnum.FILE_RAW}?filepath=${encodeURIComponent(filepath)}&workspace=${encodeURIComponent(workspace)}`
      : `${ApiRoutePathEnum.FILE_RAW}?filepath=${encodeURIComponent(filepath)}`

    return (
      <span
        className={cn(
          'flex items-center justify-center rounded-md text-xs font-medium',
          'p-1 bg-transparent border border-transparent transition-all duration-200',
          'text-gray-500 dark:text-gray-400 cursor-pointer',
          'hover:bg-gray-100 dark:hover:bg-white/10',
          'focus:outline-hidden focus:ring-2 focus:ring-blue-300/50',
          'disabled:opacity-50 disabled:cursor-default',
        )}
      >
        <a
          title="Open as raw"
          href={url}
          target="_blank"
          className="inline-flex cursor-pointer items-center text-blue-600 hover:text-blue-800 dark:text-blue-400 dark:hover:text-blue-300 transition-colors"
          rel="noreferrer"
        >
          <svg
            width="14"
            height="14"
            viewBox="0 0 24 24"
            fill="none"
            stroke="currentColor"
            strokeWidth="2"
            strokeLinecap="round"
            strokeLinejoin="round"
          >
            <path d="M18 13v6a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V8a2 2 0 0 1 2-2h6" />
            <polyline points="15,3 21,3 21,9" />
            <line x1="10" y1="14" x2="21" y2="3" />
          </svg>
        </a>
      </span>
    )
  }
}
