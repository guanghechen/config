import React from 'react'
import { Composer } from './Composer'
import { PdfViewProvider } from './context'

interface IProps {
  readonly workspace: string | null
  readonly filepath: string
  readonly filepathDirtyTick: number
}

export class PdfView extends React.PureComponent<IProps> {
  public static readonly displayName = 'PdfView'

  public override render(): React.ReactElement {
    const { workspace, filepath, filepathDirtyTick } = this.props

    return (
      <PdfViewProvider
        workspace={workspace}
        filepath={filepath}
        filepathDirtyTick={filepathDirtyTick}
      >
        <Composer />
      </PdfViewProvider>
    )
  }
}
