import { isEqual } from '@guanghechen/equal'
import { State } from '@guanghechen/viewmodel'
import { Reporter } from '@/shared/reporter'
import type { IServerSettings } from '@/shared/types/setting'
import { serverSettingsResolver } from '@/shared/util/setting'

export const states = {
  $settings: new State<IServerSettings>(serverSettingsResolver.defaults(), { equals: isEqual }),
}

export const senderMap: Map<string, number> = new Map()
export const reporter = new Reporter({
  name: 'wulala.server',
  date: true,
  getLevel: () => states.$settings.getSnapshot().loglevel,
})
