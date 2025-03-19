import type { IResponsePayloadWorkspaces } from '../../../../shared/types'
import state from '../../../state'
import type { IApiHandle, IApiHandleResult } from '../types'

// export const list_workspace_files: IApiHandle = async (params: IApiHandleParams): Promise<boolean> => {
//   const { res, searchParams } = params
//
//   const workspace: string | null = searchParams.get('workspace') || null
//   const item = workspace ? state.workspaceMap$.getSnapshot().get(workspace) : undefined
//   if (!item) {
//   }
//
//   const data: IResponsePayloadWorkspaces = {
//     workspaces: Array.from(state.workspaceMap$.getSnapshot().values()).map(item => ({
//       tag: item.tag,
//     })),
//   }
//
//   res.statusCode = 200
//   res.setHeader('Content-Type', 'application/json')
//   res.end(JSON.stringify(data))
//   return true
// }

export const list_workspaces: IApiHandle = async () => {
  const data: IResponsePayloadWorkspaces = {
    workspaces: Array.from(state.workspaceMap$.getSnapshot().values()).map(item => ({
      tag: item.tag,
    })),
  }
  const result: IApiHandleResult = {
    code: 200,
    data: { data },
  }
  return result
}
