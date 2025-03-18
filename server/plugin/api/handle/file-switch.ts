import path from 'node:path'
import state from '../../../state'
import { resolveShortFilepath } from '../../../util/path'
import type { IApiHandle, IApiHandleParams } from '../types'

export const file_switch: IApiHandle = async (params: IApiHandleParams): Promise<boolean> => {
  const { searchParams, res } = params

  const force: boolean =
    decodeURIComponent(searchParams.get('force') ?? '').toLowerCase() === 'true'
  let filepath: string = decodeURIComponent(searchParams.get('filepath') ?? '')
  filepath = resolveShortFilepath(filepath ? path.normalize(filepath) : '')
  state.fileSwitchArgForce$.next(force)
  state.fileSwitch$.next(filepath)

  const data = { succeed: true }
  res.statusCode = 200
  res.setHeader('Content-Type', 'application/json')
  res.end(JSON.stringify(data))
  return true
}
