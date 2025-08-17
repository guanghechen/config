import React from 'react'

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
      ? `/api/file/raw?filepath=${encodeURIComponent(filepath)}&workspace=${encodeURIComponent(workspace)}`
      : `/api/file/raw?filepath=${encodeURIComponent(filepath)}`

    return (
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
    )
  }
}
