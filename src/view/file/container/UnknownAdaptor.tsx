import React from 'react'
import { UnknownView } from '@/view/filetype/unknown/View'

interface IProps {
  readonly workspace: string | null
  readonly filepath: string | null
  readonly filepathDirtyTick: number
}

export const UnknownAdaptor: React.FC<IProps> = ({ filepath }) => {
  return <UnknownView filepath={filepath} />
}
