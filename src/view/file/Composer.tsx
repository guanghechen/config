import { useStateValue } from '@guanghechen/react-viewmodel'
import React from 'react'
import { useFileViewmodel } from './context'
import { Main } from './layout/main'

export const Composer: React.FC = () => {
  const viewmodel = useFileViewmodel()
  const filepath = useStateValue(viewmodel.filepath$)
  const filepathDirtyTick: number = useStateValue(viewmodel.filepathDirtyTick$)
  return <Main filepath={filepath} filepathDirtyTick={filepathDirtyTick} />
}

Composer.displayName = 'FileComposer'
