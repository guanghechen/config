import React from 'react'
import { TotopButton } from '@/component/button/totop'
import { Composer } from './Composer'
import { SvgViewProvider } from './context'

interface IProps {
  readonly workspace: string | null
  readonly filepath: string
  readonly filepathDirtyTick: number
  readonly mainScrollableContainer: HTMLDivElement | null
}

export class SvgView extends React.PureComponent<IProps> {
  public static readonly displayName = 'SvgView'

  public override render(): React.ReactElement {
    const { filepath, workspace, filepathDirtyTick, mainScrollableContainer } = this.props

    if (!filepath) {
      return (
        <div className="relative size-full flex items-center">
          <div className="text-center text-gray-500 dark:text-gray-400">No file specified</div>
        </div>
      )
    }

    return (
      <SvgViewProvider
        workspace={workspace}
        filepath={filepath}
        filepathDirtyTick={filepathDirtyTick}
      >
        <div className="relative size-full">
          <Composer />
          <TotopButton scrollableContainer={mainScrollableContainer} />
        </div>
      </SvgViewProvider>
    )
  }
}
