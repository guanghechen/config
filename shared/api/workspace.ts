import { ApiRoutePathEnum } from '../constant/api'
import { requester } from './requester'

export interface IWorkspaceItem {
  readonly tag: string
}

export class WorkspaceController {
  public async list(): Promise<IWorkspaceItem[]> {
    const url = ApiRoutePathEnum.WORKSPACES
    const response = await requester.get(url)
    const { error, details, data } = await response.json()
    if (error || details || !data) {
      console.error('Failed to fetch workspaces:', { error, details, data })
      return []
    }
    return data.workspaces
  }

  public async files(workspace: string | null): Promise<string[]> {
    if (!workspace) return []

    const ups = new URLSearchParams()
    ups.set('workspace', workspace)
    const search = '?' + ups.toString()

    const url = `${ApiRoutePathEnum.WORKSPACE_FILES}${search}`
    const response = await requester.get(url)
    const { error, details, data } = await response.json()
    if (error || details || !data) {
      console.error('Failed to fetch workspace files:', { error, details, data })
      return []
    }
    return data.files
  }
}

export const workspaceController = new WorkspaceController()
