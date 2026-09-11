import { useStateValue, useViewModel } from '@guanghechen/react-viewmodel'
import React from 'react'
import { usePersistAsync } from '@/common/hook/usePersistAsync'
import { universalStorage } from '@/common/util/storage'
import type { IPaletteColors } from '@/common/style/palette'
import { DARK_PALETTES, LIGHT_PALETTES } from '@/common/style/palette'
import type { ISiteContext } from './context'
import { SiteContextType } from './context'
import type { ISiteData } from './viewmodel'
import { SiteTheme, SiteViewModel } from './viewmodel'

const storageKey: string = '#/context/site'
const palettes = [...LIGHT_PALETTES, ...DARK_PALETTES]

interface ISideEffectProps {
  readonly viewmodel: SiteViewModel
}

export const SiteContextProvider: React.FC<{ children: React.ReactNode }> = props => {
  const viewmodel: SiteViewModel | null = useViewModel<SiteViewModel>(async () => {
    const initialData = await universalStorage.getContext<Partial<ISiteData>>(storageKey)
    const deviceTheme = window.matchMedia('(prefers-color-scheme: dark)').matches
      ? SiteTheme.DARKEN
      : SiteTheme.LIGHTEN
    return SiteViewModel.fromData(initialData || {}, deviceTheme)
  })

  const context: ISiteContext | null = React.useMemo<ISiteContext | null>(
    () => (viewmodel ? { viewmodel } : null),
    [viewmodel],
  )

  if (!viewmodel || !context) return <React.Fragment />

  return (
    <React.Fragment>
      <SiteContextType.Provider value={context}>{props.children}</SiteContextType.Provider>
      <SideEffect viewmodel={viewmodel} />
    </React.Fragment>
  )
}
SiteContextProvider.displayName = 'SiteContextProvider'

// /////////////////////////////////////////////////////////////////////////////////////////////////

const SideEffect: React.FC<ISideEffectProps> = props => {
  const { viewmodel } = props
  const theme: SiteTheme = useStateValue(viewmodel.theme$)
  const palette = useStateValue(viewmodel.palette$)

  // Theme choices are infrequent; do not leave a pending preference behind a quick reload.
  usePersistAsync(
    viewmodel,
    storageKey,
    [viewmodel.themePreference$, viewmodel.lightPalette$, viewmodel.darkPalette$],
    { throttleMs: 0 },
  )

  React.useLayoutEffect(() => {
    const media = window.matchMedia('(prefers-color-scheme: dark)')
    const updateDeviceTheme = (): void => {
      viewmodel.setDeviceTheme(media.matches ? SiteTheme.DARKEN : SiteTheme.LIGHTEN)
    }
    media.addEventListener('change', updateDeviceTheme)
    updateDeviceTheme()
    return () => media.removeEventListener('change', updateDeviceTheme)
  }, [viewmodel])

  React.useLayoutEffect(() => {
    const darken = theme === SiteTheme.DARKEN
    if (darken) {
      document.documentElement.classList.add('dark')
    } else {
      document.documentElement.classList.remove('dark')
    }
  }, [theme])

  React.useLayoutEffect(() => {
    const root = document.documentElement
    const definition = palettes.find(item => item.id === palette)
    if (!definition) return

    root.dataset.palette = palette
    const properties: string[] = []
    for (const [key, value] of Object.entries(definition.colors) as Array<
      [keyof IPaletteColors, string]
    >) {
      const property = `--palette-${key.replace(/[A-Z]/g, char => `-${char.toLowerCase()}`)}`
      root.style.setProperty(property, value)
      properties.push(property)
    }
    return () => {
      if (root.dataset.palette === palette) delete root.dataset.palette
      for (const property of properties) root.style.removeProperty(property)
    }
  }, [palette])

  return <React.Fragment />
}
SideEffect.displayName = 'SiteContextSideEffect'
