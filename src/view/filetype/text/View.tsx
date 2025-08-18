import React from 'react'
import { TotopButton } from '@/component/button/totop'
import { Composer } from './Composer'
import { TextViewProvider } from './context'
import './style.css'

interface IProps {
  readonly workspace: string | null
  readonly filepath: string | null
  readonly filepathDirtyTick: number
  readonly mainScrollableContainer: HTMLDivElement | null
}

export class TextView extends React.PureComponent<IProps> {
  public static readonly displayName = 'TextView'

  public override render(): React.ReactElement {
    const { filepath, workspace, filepathDirtyTick, mainScrollableContainer } = this.props

    if (!filepath) {
      return (
        <div className="box-border relative size-full flex items-center">
          <div className="text-center text-gray-500 dark:text-gray-400">No file specified</div>
        </div>
      )
    }

    return (
      <TextViewProvider
        workspace={workspace}
        filepath={filepath}
        filepathDirtyTick={filepathDirtyTick}
      >
        <div className="box-border relative size-full">
          <Composer />
          <TotopButton scrollableContainer={mainScrollableContainer} />
        </div>
      </TextViewProvider>
    )
  }
}
