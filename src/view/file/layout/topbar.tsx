import { useStateValue } from '@guanghechen/react-viewmodel'
import React from 'react'
import { FilePath } from '@/component/FilePath'
import { useFileViewmodel } from '../context'

export const Topbar: React.FC = () => {
  const viewmodel = useFileViewmodel()
  const filepath = useStateValue(viewmodel.filepath$)

  return (
    <div className="f-vf-topbar">
      {filepath && <FilePath filepath={filepath} workspace={null} />}
    </div>
  )
}
