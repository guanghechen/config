// Tokenize one literal command with optional redirections. Unsupported syntax
// returns null for the entire input; never scan script bodies or infer shell state.
const REDIRECTS = ["&>>", "&>", ">>", "<&", ">&", "<>", ">|", "<", ">"]

export function shellWords(source) {
  const tokens = []
  let value = ""
  let started = false
  let quoted = false
  let expandHome = false
  let ended = false
  let index = 0

  function append(text) {
    started = true
    value += text
  }

  function flush() {
    if (!started) return
    tokens.push({ type: "word", value, expandHome })
    value = ""
    started = quoted = expandHome = false
  }

  while (index < source.length) {
    const char = source[index]
    if (char === " " || char === "\t" || char === "\n") {
      flush()
      if (char === "\n" && tokens.length) ended = true
      index++
      continue
    }
    if (char === "#" && !started) {
      const end = source.indexOf("\n", index)
      index = end < 0 ? source.length : end
      continue
    }
    if (ended) return null
    if (char === "\\") {
      if (index + 1 >= source.length) return null
      if (source[index + 1] !== "\n") { append(source[index + 1]); quoted = true }
      index += 2
      continue
    }
    if (char === "'" || char === '"') {
      const quote = char
      append("")
      quoted = true
      index++
      while (index < source.length && source[index] !== quote) {
        const next = source[index]
        if (quote === '"' && (next === "$" || next === "`")) return null
        if (quote === '"' && next === "\\" && /[$`"\\\n]/.test(source[index + 1] ?? "")) {
          if (source[index + 1] !== "\n") append(source[index + 1])
          index += 2
        } else {
          append(source[index++])
        }
      }
      if (index >= source.length) return null
      index++
      continue
    }
    if (source.startsWith("<<", index)) return null
    const redirect = REDIRECTS.find((operator) => source.startsWith(operator, index))
    if (redirect) {
      if (/^[<>]/.test(redirect) && /^\d+$/.test(value) && !quoted) {
        value = ""
        started = false
      }
      flush()
      tokens.push({ type: "operator", value: redirect })
      index += redirect.length
      continue
    }
    if (/[;&|(){}$`*?\[\]]/.test(char)) return null
    if (!started && char === "~") {
      if (source[index + 1] !== "/") return null
      expandHome = true
    }
    // CR and other whitespace remain literal, as they do in Bash.
    append(char)
    index++
  }
  flush()
  return tokens
}
