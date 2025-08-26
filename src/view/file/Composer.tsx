import { useStateValue } from '@guanghechen/react-viewmodel'
import React from 'react'
import { useFileViewmodel } from './context'
import { Main } from './layout/main'
import { Topbar } from './layout/topbar'

const storageKeyScope = '#/view/file'

export const Composer: React.FC = () => {
  const viewmodel = useFileViewmodel()
  const filepath = useStateValue(viewmodel.filepath$)
  const filepathDirtyTick: number = useStateValue(viewmodel.filepathDirtyTick$)

  return (
    <div className="f-vf-root">
      <Topbar filepath={filepath} />
      <Main
        filepath={filepath}
        filepathDirtyTick={filepathDirtyTick}
        storageKeyScope={storageKeyScope}
      />
    </div>
  )
}

Composer.displayName = 'FileViewComposer'
