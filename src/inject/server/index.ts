async function setup(): Promise<void> {
  console.debug('[tsuki.server] setted up!')
}

void setup().catch(error => {
  console.error(error)
})
