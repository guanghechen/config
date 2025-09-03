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
  file: React.lazy(() => import('@/view/file/View').then(md => ({ default: md.FileView }))),
  notfound: React.lazy(() => import('@/view/not-found').then(md => ({ default: md.NotFoundView }))),
  workspace: React.lazy(() =>
    import('@/view/workspace/View').then(md => ({ default: md.WorkspaceView })),
  ),
  whiteboard: React.lazy(() =>
    import('@/view/whiteboard/View').then(md => ({ default: md.WhiteboardView })),
  ),
}

export const routes: IRouteItem[] = [
  {
    key: 'workspace',
    path: '/ws/:workspace_name',
    label: 'Workspace',
    listed: true,
    Component: views.workspace,
  },
  {
    key: 'whiteboard',
    path: '/whiteboard',
    label: 'Whiteboard',
    listed: true,
    Component: views.whiteboard,
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
