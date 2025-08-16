import path from 'node:path'
import state from '../../../../state'
import type { IApiHandle, IApiHandleData } from '../../types'

export const switchFile: IApiHandle = async params => {
  const { searchParams } = params

  const force: boolean =
    decodeURIComponent(searchParams.get('force') ?? '').toLowerCase() === 'true'
  const filepath: string = decodeURIComponent(searchParams.get('filepath') ?? '')
  state.fileSwitchArgForce$.next(force)
  state.fileSwitch$.next(path.normalize(filepath))

  const data: IApiHandleData = {
    data: { succeed: true },
  }
  return { code: 200, data }
}
