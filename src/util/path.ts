const regexes = {
  extname: /(\.[^.]+)$/,
}

export const calcExtname = (filepath: string | null): stirng => {
  const extname: string = filepath ? regexes.extname.exec(filepath)?.[1] || '' : ''
  return extname
}
