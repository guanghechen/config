import React from 'react'
import { Composer } from './Composer'
import { ModeToggle } from './container/ModeToggle'
import { TextViewProvider } from './context'

interface IProps {
  readonly workspace: string | null
  readonly filepath: string | null
  readonly filepathDirtyTick: number
  readonly mainScrollableContainer: HTMLDivElement | null
}

export const TextView: React.FC<IProps> = props => {
  const { filepath, workspace, filepathDirtyTick, mainScrollableContainer } = props

  return (
    <div className="size-screen">
      <div className="relative w-full">
        <TextViewProvider
          workspace={workspace}
          filepath={filepath}
          filepathDirtyTick={filepathDirtyTick}
        >
          <ModeToggle />
          <div className="relative w-full">
            <Composer
              workspace={workspace}
              filepath={filepath}
              mainScrollableContainer={mainScrollableContainer}
            />
          </div>
        </TextViewProvider>
      </div>
    </div>
  )
}

TextView.displayName = 'TextView'
