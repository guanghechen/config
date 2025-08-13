import React from 'react'
import { Composer } from './Composer'
import { TailwindToggle } from './container/TailwindToggle'
import { HtmlViewProvider } from './context'

interface IProps {
  readonly workspace: string | null
  readonly filepath: string | null
  readonly filepathDirtyTick: number
  readonly mainScrollableContainer: HTMLDivElement | null
  readonly topbarVisible: boolean
}

export const HtmlView: React.FC<IProps> = props => {
  const { filepath, workspace, filepathDirtyTick, mainScrollableContainer, topbarVisible } = props

  return (
    <div className="w-full pt-8">
      <div className="relative w-full">
        <HtmlViewProvider
          workspace={workspace}
          filepath={filepath}
          filepathDirtyTick={filepathDirtyTick}
        >
          <TailwindToggle topbarVisible={topbarVisible} />
          <Composer
            workspace={workspace}
            filepath={filepath}
            mainScrollableContainer={mainScrollableContainer}
          />
        </HtmlViewProvider>
      </div>
    </div>
  )
}

HtmlView.displayName = 'HtmlView'
