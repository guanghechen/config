import { useEffect, useRef, useState } from 'react'
import {
  DEFAULT_APPEARANCE_SETTINGS,
  readAppearanceSettings,
  type AppearanceMode,
  type IAppearanceSettings,
  writeAppearanceSettings,
} from '@/shared/setting/appearance'
import { writePageEnabled } from '@/shared/setting/page-enabled'
import type { ThemeKind } from '@/shared/theme/contract'
import { isThemeIdForKind } from '@/shared/theme/registry'
import { readActivePageStatus, type IActivePageStatus } from '../service/active-page'

type SavingTarget = 'appearance' | 'page' | null

export interface IAppearanceViewModel {
  readonly appearanceControlDisabled: boolean
  readonly appearanceSettings: IAppearanceSettings
  readonly errorMessage: string | null
  readonly isBusy: boolean
  readonly pageStatus: IActivePageStatus | null
  readonly statusMessage: string
  readonly updateMode: (mode: AppearanceMode) => void
  readonly updatePageEnabled: (enabled: boolean) => void
  readonly updateTheme: (kind: ThemeKind, value: string) => void
}

export function useAppearance(): IAppearanceViewModel {
  const [appearanceSettings, setAppearanceSettings] = useState<IAppearanceSettings>(
    DEFAULT_APPEARANCE_SETTINGS,
  )
  const [pageStatus, setPageStatus] = useState<IActivePageStatus | null>(null)
  const [isLoading, setIsLoading] = useState(true)
  const [savingTarget, setSavingTarget] = useState<SavingTarget>(null)
  const savingTargetRef = useRef<SavingTarget>(null)
  const [errorMessage, setErrorMessage] = useState<string | null>(null)

  useEffect(() => {
    let active = true

    void Promise.allSettled([readAppearanceSettings(), readActivePageStatus()]).then(
      ([appearanceResult, pageResult]) => {
        if (!active) return

        const errors: string[] = []
        if (appearanceResult.status === 'fulfilled') setAppearanceSettings(appearanceResult.value)
        else errors.push('Could not load the appearance settings.')

        if (pageResult.status === 'fulfilled') setPageStatus(pageResult.value)
        else errors.push('Could not check the current page.')

        setErrorMessage(errors.length > 0 ? errors.join(' ') : null)
        setIsLoading(false)
      },
    )

    return () => {
      active = false
    }
  }, [])

  useEffect(() => {
    document.documentElement.dataset.theme = appearanceSettings.mode
  }, [appearanceSettings.mode])

  async function updatePageEnabledValue(enabled: boolean): Promise<void> {
    if (!pageStatus || savingTargetRef.current !== null || enabled === pageStatus.enabled) return

    const previousStatus = pageStatus
    savingTargetRef.current = 'page'
    setPageStatus({ ...pageStatus, enabled })
    setSavingTarget('page')
    setErrorMessage(null)

    try {
      await writePageEnabled(pageStatus.url, enabled)
    } catch {
      setPageStatus(previousStatus)
      setErrorMessage('Could not update this site. The previous setting was restored.')
    } finally {
      savingTargetRef.current = null
      setSavingTarget(null)
    }
  }

  function updatePageEnabled(enabled: boolean): void {
    void updatePageEnabledValue(enabled)
  }

  async function updateAppearanceSettings(nextValue: IAppearanceSettings): Promise<void> {
    if (savingTargetRef.current !== null || isSameAppearanceSettings(nextValue, appearanceSettings))
      return

    const previousValue = appearanceSettings
    savingTargetRef.current = 'appearance'
    setAppearanceSettings(nextValue)
    setSavingTarget('appearance')
    setErrorMessage(null)

    try {
      await writeAppearanceSettings(nextValue)
    } catch {
      setAppearanceSettings(previousValue)
      setErrorMessage('Could not save the appearance. The previous settings were restored.')
    } finally {
      savingTargetRef.current = null
      setSavingTarget(null)
    }
  }

  function updateMode(mode: AppearanceMode): void {
    void updateAppearanceSettings({ ...appearanceSettings, mode })
  }

  function updateTheme(kind: ThemeKind, value: string): void {
    if (!isThemeIdForKind(value, kind)) return

    const nextValue: IAppearanceSettings =
      kind === 'light'
        ? { ...appearanceSettings, lightTheme: value }
        : { ...appearanceSettings, darkTheme: value }
    void updateAppearanceSettings(nextValue)
  }

  const isBusy = isLoading || savingTarget !== null
  const appearanceControlDisabled = isBusy || pageStatus?.enabled === false
  const statusMessage =
    errorMessage ??
    (isLoading
      ? 'Checking this page…'
      : savingTarget === 'page'
        ? 'Updating this site…'
        : savingTarget === 'appearance'
          ? 'Saving appearance…'
          : '')

  return {
    appearanceControlDisabled,
    appearanceSettings,
    errorMessage,
    isBusy,
    pageStatus,
    statusMessage,
    updateMode,
    updatePageEnabled,
    updateTheme,
  }
}

function isSameAppearanceSettings(left: IAppearanceSettings, right: IAppearanceSettings): boolean {
  return (
    left.mode === right.mode &&
    left.lightTheme === right.lightTheme &&
    left.darkTheme === right.darkTheme
  )
}
