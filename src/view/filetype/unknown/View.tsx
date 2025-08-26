import React from 'react'
import { Composer } from './Composer'
import { UnknownViewProvider } from './context'

interface IProps {
  readonly filepath: string | null
  readonly storageKeyScope: string
}

export class UnknownView extends React.PureComponent<IProps> {
  public static readonly displayName = 'UnknownView'

  public override render(): React.ReactElement {
    const { filepath, storageKeyScope } = this.props

    if (!filepath) {
      return (
        <div className="relative size-full flex items-center">
          <div className="text-center text-gray-500 dark:text-gray-400">No file specified</div>
        </div>
      )
    }

    return (
      <UnknownViewProvider storageKeyScope={storageKeyScope}>
        <div className="relative size-full">
          <Composer filepath={filepath} />
        </div>
      </UnknownViewProvider>
    )
  }
}
