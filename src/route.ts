import React from 'react'

export interface IRouteItem {
  readonly key: string
  readonly path: string
  readonly label: string
  readonly icon?: React.ReactNode
  readonly Component: React.ComponentType<any>
}

export const views = {
  workspace: React.lazy(() =>
    import('@/view/workspace/View').then(md => ({ default: md.WorkspaceView })),
  ),
  file: React.lazy(() => import('@/view/file/View').then(md => ({ default: md.FileView }))),
  notfound: React.lazy(() => import('@/view/not-found').then(md => ({ default: md.NotFoundView }))),
}

export const routes: IRouteItem[] = [
  {
    key: 'workspace',
    path: '/ws',
    label: 'Workspace',
    Component: views.workspace,
  },
  {
    key: 'file',
    path: '/file',
    label: 'File',
    Component: views.file,
  },
]
