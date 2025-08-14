import React from 'react'
import { Composer } from './Composer'
import { TextViewProvider } from './context'

interface IProps {
  readonly workspace: string | null
  readonly filepath: string | null
  readonly filepathDirtyTick: number
  readonly mainScrollableContainer: HTMLDivElement | null
  readonly topbarVisible: boolean
}

export const TextView: React.FC<IProps> = props => {
  const { filepath, workspace, filepathDirtyTick, mainScrollableContainer } = props

  return (
    <div className="w-full pt-8">
      <div className="relative w-full">
        <TextViewProvider
          workspace={workspace}
          filepath={filepath}
          filepathDirtyTick={filepathDirtyTick}
        >
          <Composer
            workspace={workspace}
            filepath={filepath}
            mainScrollableContainer={mainScrollableContainer}
          />
        </TextViewProvider>
      </div>
    </div>
  )
}

TextView.displayName = 'TextView'
