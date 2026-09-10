import state from '../../../../state'
import type { IApiHandle } from '../../types'

export const list_workspaces: IApiHandle = async () => ({
  code: 200,
  data: {
    data: {
      defaultWorkspaceRoots: state.defaultWorkspaceRoots,
      legacyWorkspaces: state.legacyWorkspaces,
    },
  },
})
