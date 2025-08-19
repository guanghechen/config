import React from 'react'
import { Composer } from './Composer'
import { MarkdownViewProvider } from './context'
import './style.css'

interface IProps {
  readonly filepath: string
  readonly workspace: string | null
  readonly filepathDirtyTick: number
  readonly mainScrollableContainer: HTMLDivElement | null
}

export class MarkdownView extends React.PureComponent<IProps> {
  public static readonly displayName = 'MarkdownView'

  public override render(): React.ReactElement {
    const { workspace, filepath, filepathDirtyTick } = this.props

    return (
      <MarkdownViewProvider
        workspace={workspace}
        filepath={filepath}
        filepathDirtyTick={filepathDirtyTick}
      >
        <Composer filepath={filepath} workspace={workspace} />
      </MarkdownViewProvider>
    )
  }
}
