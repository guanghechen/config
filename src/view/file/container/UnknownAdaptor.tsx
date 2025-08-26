import React from 'react'
import { UnknownView } from '@/view/filetype/unknown/View'

interface IProps {
  readonly workspace: string | null
  readonly filepath: string | null
  readonly filepathDirtyTick: number
  readonly storageKeyScope: string
}

export const UnknownAdaptor: React.FC<IProps> = ({ filepath, storageKeyScope }) => {
  return <UnknownView filepath={filepath} storageKeyScope={storageKeyScope} />
}
