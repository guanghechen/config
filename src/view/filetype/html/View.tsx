import React from 'react'
import { Composer } from './Composer'
import { HtmlViewProvider } from './context'

interface IProps {
  readonly workspace: string | null
  readonly filepath: string | null
  readonly mainScrollableContainer: HTMLDivElement | null
}

export const HtmlView: React.FC<IProps> = props => {
  const { filepath, workspace, mainScrollableContainer } = props

  return (
    <div className="w-full pt-8">
      <div className="relative w-full">
        <HtmlViewProvider workspace={workspace} filepath={filepath}>
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
