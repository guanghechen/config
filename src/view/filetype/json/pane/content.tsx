import { useStateValue } from '@guanghechen/react-viewmodel'
import React from 'react'
import { Json } from '@/component/json'
import { useJsonViewViewModel } from '../context'
import { DEFAULT_JSON } from '../mock-data'

export const ContentPane: React.FC = () => {
  const viewmodel = useJsonViewViewModel()
  const json = useStateValue(viewmodel.json$)

  const displayJson = json ?? DEFAULT_JSON

  return (
    <div className="box-border size-full whitespace-nowrap">
      <Json json={displayJson} />
    </div>
  )
}

ContentPane.displayName = 'JsonViewLiteralPane'
