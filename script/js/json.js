/**
 * Sometimes the command line output is not the standard JSON line format, which the lineending is
 * not the hard boundary of a item.
 *
 * @param {string} text
 * @return {any[]}
 */
function parse_json_line(text) {
  const lines = text.split(/\n/g).filter((x) => !!x);
  const items = [];

  for (let i = 0, j; i < lines.length; i = j) {
    for (j = i + 1; j <= lines.length; j++) {
      try {
        const s = lines.slice(i, j).join("");
        const item = JSON.parse(s);
        items.push(item);
        break;
      } catch (e) {}
    }
  }

  return items;
}
