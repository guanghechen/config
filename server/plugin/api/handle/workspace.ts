import type { IResponsePayloadWorkspaces } from '../../../../shared/types'
import state from '../../../state'
import { findMarkdownFiles } from '../../../util/workspace'
import type { IApiHandle, IApiHandleResult } from '../types'

export const list_workspace_files: IApiHandle = async params => {
  const { searchParams } = params

  const workspace: string | null = searchParams.get('workspace') || null
  const item = workspace ? state.workspaceMap$.getSnapshot().get(workspace) : undefined
  if (!item) {
    const result: IApiHandleResult = {
      code: 404,
      data: {
        data: null,
        error: 'Workspace not found',
        details: {
          workspace,
        },
      },
    }
    return result
  }

  const force = searchParams.has('force') && searchParams.get('force') !== 'false'
  if (!item.files.mds || !force) {
    const files = await findMarkdownFiles(item.path)
    item.files.mds = files
    const result: IApiHandleResult = {
      code: 200,
      data: { data: { files } },
    }
    return result
  } else {
    const files = item.files.mds
    const result: IApiHandleResult = {
      code: 200,
      data: { data: { files } },
    }
    return result
  }
}

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
