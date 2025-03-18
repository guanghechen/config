import type { IResponsePayloadWorkspaces } from '../../../../shared/types'
import state from '../../../state'
import type { IApiHandle, IApiHandleParams } from '../types'

export const workspaces: IApiHandle = async (params: IApiHandleParams): Promise<boolean> => {
  const { res } = params

  const data: IResponsePayloadWorkspaces = {
    workspaces: Array.from(state.workspaceMap$.getSnapshot().values()).map(item => ({
      tag: item.tag,
    })),
  }

  res.statusCode = 200
  res.setHeader('Content-Type', 'application/json')
  res.end(JSON.stringify(data))
  return true
}
