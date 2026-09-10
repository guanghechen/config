import { ApiRoutePathEnum } from '../constant/api'
import type { IWorkspaceConfig, IWorkspaceFiles } from '../types/workspace'
import { requester } from './requester'

export class WorkspaceController {
  public async list(): Promise<IWorkspaceConfig> {
    const url = ApiRoutePathEnum.WORKSPACES
    const response = await requester.get(url)
    const { error, details, data } = await response.json()
    if (error || details || !data) {
      throw new Error(error || details || 'Failed to fetch workspace configuration')
    }
    return data
  }

  public async files(root: string): Promise<IWorkspaceFiles> {
    const ups = new URLSearchParams()
    ups.set('root', root)
    const search = '?' + ups.toString()

    const url = `${ApiRoutePathEnum.WORKSPACE_FILES}${search}`
    const response = await requester.get(url)
    const { error, details, data } = await response.json()
    if (error || details || !data) {
      throw new Error(error || details || 'Failed to fetch workspace files')
    }
    return data
  }
}

export const workspaceController = new WorkspaceController()
