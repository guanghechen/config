import state from '../../../../state.ts'
import type { IApiHandle } from '../../types.ts'

export const list_workspaces: IApiHandle = async () => ({
  code: 200,
  data: {
    data: {
      defaultWorkspaceRoots: state.defaultWorkspaceRoots,
      legacyWorkspaces: state.legacyWorkspaces,
    },
  },
})
