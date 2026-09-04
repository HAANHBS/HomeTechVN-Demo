import worker from '../worker/src/index.js'

function assert(condition, message) {
  if (!condition) throw new Error(message)
}

async function responseJson(response) {
  return { status: response.status, body: await response.json() }
}

const health = await responseJson(await worker.fetch(new Request('https://worker.invalid/health'), {}))
assert(health.status === 200, 'health endpoint must return HTTP 200 without secrets')
assert(health.body.ok === true, 'health endpoint payload mismatch')

const unauthorized = await responseJson(await worker.fetch(
  new Request('https://worker.invalid/run', {
    method: 'POST',
    headers: { 'x-hometech-worker-key': 'wrong' },
  }),
  { WORKER_TRIGGER_KEY: 'expected' },
))
assert(unauthorized.status === 401, 'manual run must reject a wrong trigger key')
assert(unauthorized.body.error === 'unauthorized', 'unauthorized payload mismatch')

let waitUntilCalls = 0
await worker.scheduled({}, { WORKER_CRON_ENABLED: 'false' }, {
  waitUntil() { waitUntilCalls += 1 },
})
assert(waitUntilCalls === 0, 'disabled cron must not start the notification pipeline')

const missing = await responseJson(await worker.fetch(new Request('https://worker.invalid/missing'), {}))
assert(missing.status === 404, 'unknown route must return HTTP 404')

console.log('T18 WORKER HEALTH/UNAUTHORIZED CONTRACT: PASS')
console.log('T18 WORKER CRON-OFF SAFETY SELF TEST: PASS')
