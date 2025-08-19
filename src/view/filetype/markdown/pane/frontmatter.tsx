import { useStateValue } from '@guanghechen/react-viewmodel'
import React from 'react'
import { Json } from '@/component/json'
import { useMarkdownViewViewModel } from '../context'

export const FrontmatterPane: React.FC = () => {
  const viewmodel = useMarkdownViewViewModel()
  const data = useStateValue(viewmodel.data$)
  const frontmatter: Record<string, unknown> | undefined = data?.frontmatter

  return (
    <div className="box-border flex-auto">
      <h3 className="text-lg p-0 m-0 mb-4 font-medium text-gray-800 dark:text-gray-100">
        Frontmatter
      </h3>
      <Json json={frontmatter} initialCollapsed="expanded" />
    </div>
  )
}

FrontmatterPane.displayName = 'FrontmatterPane'
