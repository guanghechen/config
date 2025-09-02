import { useStateValue } from '@guanghechen/react-viewmodel'
import React from 'react'
import { FilePath } from '@/component/FilePath'
import { useFileViewmodel } from '../context'

export const Topbar: React.FC = () => {
  const viewmodel = useFileViewmodel()
  const filepath = useStateValue(viewmodel.filepath$)

  return (
    <React.Fragment>{filepath && <FilePath filepath={filepath} workspace={null} />}</React.Fragment>
  )
}
