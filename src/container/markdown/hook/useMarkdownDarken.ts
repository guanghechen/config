import { useStateValue } from '@guanghechen/react-viewmodel'
import { useMarkdownTopViewmodel } from '../context/top'

export const useMarkdownDarken = (): boolean => {
  const viewmodel = useMarkdownTopViewmodel()
  const theme = useStateValue(viewmodel.themeScheme$)
  return theme === 'darken'
}
