import type { IResponsePayloadWorkspaces } from '../../../../../shared/types'
import state from '../../../../state'
import type { IApiHandle, IApiHandleResult } from '../../types'

export const list_workspaces: IApiHandle = async () => {
  const data: IResponsePayloadWorkspaces = {
    workspaces: Array.from(state.workspaceMap$.getSnapshot().values())
      .map(item => ({ tag: item.tag }))
      .sort((x, y) => x.tag.localeCompare(y.tag)),
  }
  const result: IApiHandleResult = {
    code: 200,
    data: { data },
  }
  return result
}
