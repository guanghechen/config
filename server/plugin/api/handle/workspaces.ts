import state from '../../../state'
import type { IApiHandle, IApiHandleParams } from '../types'

export const workspaces: IApiHandle = async (params: IApiHandleParams): Promise<boolean> => {
  const { res } = params

  const data = Object.values(state.workspaces$.getSnapshot()).map(item => ({
    tag: item.tag,
  }))

  res.statusCode = 200
  res.setHeader('Content-Type', 'application/json')
  res.end(JSON.stringify(data))
  return true
}
