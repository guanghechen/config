import React from 'react'
import { Composer } from './Composer'
import { ModeToggle } from './container/ModeToggle'
import { HtmlViewProvider } from './context'

interface IProps {
  readonly workspace: string | null
  readonly filepath: string | null
  readonly filepathDirtyTick: number
  readonly mainScrollableContainer: HTMLDivElement | null
}

export const HtmlView: React.FC<IProps> = props => {
  const { filepath, workspace, filepathDirtyTick, mainScrollableContainer } = props

  return (
    <div className="w-full pt-8">
      <div className="relative w-full">
        <HtmlViewProvider
          workspace={workspace}
          filepath={filepath}
          filepathDirtyTick={filepathDirtyTick}
        >
          <ModeToggle />
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
