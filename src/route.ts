import React from 'react'

export interface IRouteItem {
  readonly key: string
  readonly path: string
  readonly label: string
  readonly listed: boolean
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
    listed: true,
    Component: views.workspace,
  },
  {
    key: 'workspace-named',
    path: '/ws/:workspace_name',
    label: 'Workspace',
    listed: false,
    Component: views.workspace,
  },
  {
    key: 'file',
    path: '/file',
    label: 'File',
    listed: false,
    Component: views.file,
  },
]

export const listedRoutes: IRouteItem[] = routes.filter(route => route.listed)
