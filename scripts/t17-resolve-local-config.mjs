import fs from 'node:fs'
import path from 'node:path'
import { spawnSync } from 'node:child_process'

const root=path.resolve(process.cwd())
const isWin=process.platform==='win32'
const npx=isWin?'npx.cmd':'npx'
const docker=isWin?'docker.exe':'docker'

const DEFAULT_ATTEMPTS=10
const RETRY_MS=2000

function sleep(ms){return new Promise(resolve=>setTimeout(resolve,ms))}

function cmdQuote(value){
  const s=String(value)
  if(!/[\s"&|<>^]/.test(s))return s
  return `"${s.replace(/"/g,'\\"')}"`
}

function run(cmd,args){
  let r
  const common={cwd:root,encoding:'utf8',windowsHide:true,shell:false}
  if(isWin && /\.cmd$/i.test(cmd)){
    const comspec=process.env.ComSpec||'cmd.exe'
    const line=[cmd,...args].map(cmdQuote).join(' ')
    r=spawnSync(comspec,['/d','/s','/c',line],common)
  }else{
    r=spawnSync(cmd,args,common)
  }
  return {
    ok:!r.error&&r.status===0,
    stdout:r.stdout||'',
    stderr:r.stderr||'',
    status:r.status,
    error:r.error,
  }
}

function extractJson(text){
  const first=text.indexOf('{')
  const last=text.lastIndexOf('}')
  if(first<0||last<=first)return null
  try{
    const value=JSON.parse(text.slice(first,last+1))
    return value&&typeof value==='object'?value:null
  }catch{
    return null
  }
}

function flatten(value,out={}){
  if(value===null||value===undefined)return out
  if(Array.isArray(value)){
    for(const x of value)flatten(x,out)
    return out
  }
  if(typeof value==='object'){
    for(const [key,val] of Object.entries(value)){
      if(val===null||val===undefined)continue
      if(typeof val==='string'||typeof val==='number'||typeof val==='boolean'){
        out[key.toUpperCase()]=String(val)
      }else{
        flatten(val,out)
      }
    }
  }
  return out
}

function parseEnv(text){
  const out={}
  for(const raw of text.split(/\r?\n/)){
    const m=raw.trim().match(/^([A-Z0-9_]+)=(.*)$/)
    if(!m)continue
    let value=m[2].trim()
    if(value.length>=2&&(
      (value.startsWith('"')&&value.endsWith('"'))||
      (value.startsWith("'")&&value.endsWith("'"))
    ))value=value.slice(1,-1)
    out[m[1]]=value
  }
  return out
}

function asciiClean(text){
  return text
    .replace(/\x1b\[[0-9;]*m/g,' ')
    .replace(/[^\x20-\x7E\r\n]/g,' ')
}

function parsePretty(text){
  const clean=asciiClean(text)
  let apiUrl=null
  let publishableKey=null

  const urlMatch=clean.match(
    /\b(?:Project|API)\s+URL\b\s*[:|]?\s*(https?:\/\/\S+)/i
  )
  if(urlMatch)apiUrl=urlMatch[1].replace(/[|]+$/,'')

  const keyMatch=clean.match(
    /\b(?:Publishable|anon)\b(?:\s+key)?\s*[:|]?\s*((?:sb_publishable_[A-Za-z0-9_-]+)|(?:eyJ[A-Za-z0-9._-]+))/i
  )
  if(keyMatch)publishableKey=keyMatch[1]

  return {apiUrl,publishableKey}
}

function parseConfig(text){
  let section=''
  let apiPort=54321
  let projectId=null

  for(const raw of text.split(/\r?\n/)){
    const line=raw.trim()
    let m

    if((m=line.match(/^\[([^\]]+)\]$/))){
      section=m[1].trim().toLowerCase()
      continue
    }

    if(!projectId&&(m=line.match(/^project_id\s*=\s*["']([^"']+)["']\s*$/))){
      projectId=m[1]
    }

    if(section==='api'&&(m=line.match(/^port\s*=\s*(\d+)\s*(?:#.*)?$/))){
      apiPort=Number(m[1])
    }
  }

  return {apiPort,projectId}
}

function pick(map,names,predicate=()=>true){
  for(const name of names){
    const value=map[name]
    if(value&&predicate(value))return value
  }
  return null
}

function getConfigFile(){
  const configPath=path.join(root,'supabase','config.toml')
  if(!fs.existsSync(configPath))return {apiPort:54321,projectId:null}
  return parseConfig(fs.readFileSync(configPath,'utf8'))
}

function pickStatusConfig(jsonObject){
  const map=flatten(jsonObject||{})
  const apiUrl=pick(
    map,
    ['API_URL','SUPABASE_URL','PROJECT_URL','APIURL'],
    value=>/^https?:\/\//i.test(value),
  )
  const publishableKey=pick(
    map,
    [
      'PUBLISHABLE_KEY',
      'SUPABASE_PUBLISHABLE_KEY',
      'ANON_KEY',
      'SUPABASE_ANON_KEY',
      'ANONKEY',
    ],
  )
  return {apiUrl,publishableKey,keys:Object.keys(map).sort()}
}

function resolveFromDocker(config){
  const result=run(docker,['ps','--format','{{.Names}}'])
  if(!result.ok)return {publishableKey:null,containers:[]}

  const all=result.stdout
    .split(/\r?\n/)
    .map(value=>value.trim())
    .filter(value=>value.startsWith('supabase_'))

  const preferred=config.projectId
    ? all.filter(value=>value.endsWith(`_${config.projectId}`))
    : []

  const names=preferred.length?preferred:all

  for(const name of names){
    const inspected=run(
      docker,
      ['inspect','-f','{{range .Config.Env}}{{println .}}{{end}}',name],
    )
    if(!inspected.ok)continue

    const map=parseEnv(inspected.stdout)
    const key=pick(map,[
      'PUBLISHABLE_KEY',
      'SUPABASE_PUBLISHABLE_KEY',
      'ANON_KEY',
      'SUPABASE_ANON_KEY',
      'SUPABASE_INTERNAL_PUBLISHABLE_KEY',
    ])

    if(key)return {publishableKey:key,containers:names}
  }

  return {publishableKey:null,containers:names}
}

async function discover({attempts=DEFAULT_ATTEMPTS,waitForAuth=false}={}){
  const config=getConfigFile()
  let apiUrl=null
  let publishableKey=null
  let lastJsonKeys=[]
  let lastEnvKeys=[]
  let lastContainers=[]

  const maxAttempts=waitForAuth?attempts:1

  // Supabase's own local-stack test harness retries status because DB_URL can
  // appear before GoTrue is ready, while API_URL/PUBLISHABLE_KEY are only
  // reported once Auth is up.
  for(let attempt=1;attempt<=maxAttempts;attempt++){
    const status=run(npx,['supabase','status','-o','json'])
    if(status.ok){
      const parsed=pickStatusConfig(extractJson(`${status.stdout}\n${status.stderr}`))
      apiUrl??=parsed.apiUrl
      publishableKey??=parsed.publishableKey
      lastJsonKeys=parsed.keys
    }

    if(apiUrl&&publishableKey){
      return {
        apiUrl:apiUrl.replace(/\/$/,''),
        publishableKey,
        keyKind:publishableKey.startsWith('sb_publishable_')?'publishable':'legacy-anon',
        projectId:config.projectId||null,
        source:'status-json',
        attempts:attempt,
      }
    }

    if(attempt<maxAttempts)await sleep(RETRY_MS)
  }

  // Compatibility fallbacks after the readiness retries.
  let result=run(npx,['supabase','status','-o','env'])
  if(result.ok){
    const map=parseEnv(`${result.stdout}\n${result.stderr}`)
    lastEnvKeys=Object.keys(map).sort()
    apiUrl??=pick(map,['API_URL','SUPABASE_URL'],value=>/^https?:\/\//i.test(value))
    publishableKey??=pick(map,[
      'PUBLISHABLE_KEY','SUPABASE_PUBLISHABLE_KEY',
      'ANON_KEY','SUPABASE_ANON_KEY',
    ])
  }

  if(!apiUrl||!publishableKey){
    result=run(npx,['supabase','status'])
    if(result.ok){
      const pretty=parsePretty(`${result.stdout}\n${result.stderr}`)
      apiUrl??=pretty.apiUrl
      publishableKey??=pretty.publishableKey
    }
  }

  apiUrl??=`http://127.0.0.1:${config.apiPort}`

  if(!publishableKey){
    const dockerResult=resolveFromDocker(config)
    publishableKey=dockerResult.publishableKey
    lastContainers=dockerResult.containers
  }

  if(!apiUrl)throw new Error('Could not resolve local Supabase API URL')

  const url=new URL(apiUrl)
  if(!['127.0.0.1','localhost','::1'].includes(url.hostname)){
    throw new Error(`REFUSES non-local Supabase URL: ${apiUrl}`)
  }

  if(!publishableKey){
    throw new Error(
      'Local Auth client key unavailable after readiness checks. '+
      `status-json keys=[${lastJsonKeys.join(',')}], `+
      `status-env keys=[${lastEnvKeys.join(',')}], `+
      `running Supabase containers=[${lastContainers.join(',')}]. `+
      'The full local stack must be started with `supabase start` (not only `supabase db start`).'
    )
  }

  return {
    apiUrl:apiUrl.replace(/\/$/,''),
    publishableKey,
    keyKind:publishableKey.startsWith('sb_publishable_')?'publishable':'legacy-anon',
    projectId:config.projectId||null,
    source:'fallback',
    attempts:maxAttempts,
  }
}

async function selfTest(){
  const env=parseEnv('DB_URL="postgresql://local"\nANON_KEY="eyJabc.def.ghi"')
  if(env.ANON_KEY!=='eyJabc.def.ghi')throw new Error('env parser self-test failed')

  const pretty=parsePretty(
    '| Project URL | http://127.0.0.1:54321 |\n'+
    '| Publishable | sb_publishable_test_value |'
  )
  if(pretty.apiUrl!=='http://127.0.0.1:54321'||
     pretty.publishableKey!=='sb_publishable_test_value'){
    throw new Error('pretty parser self-test failed')
  }

  const cfg=parseConfig(
    'project_id = "HOMETECHVN"\n[db]\nport=54322\n[api]\nport = 55432\n[auth]\n'
  )
  if(cfg.apiPort!==55432||cfg.projectId!=='HOMETECHVN'){
    throw new Error('config parser self-test failed')
  }

  const dbOnly=pickStatusConfig({DB_URL:'postgresql://local'})
  if(dbOnly.publishableKey!==null)throw new Error('DB-only readiness self-test failed')

  const ready=pickStatusConfig({
    DB_URL:'postgresql://local',
    API_URL:'http://127.0.0.1:54321',
    PUBLISHABLE_KEY:'sb_publishable_ready',
  })
  if(ready.apiUrl!=='http://127.0.0.1:54321'||
     ready.publishableKey!=='sb_publishable_ready'){
    throw new Error('Auth-ready status self-test failed')
  }

  console.log('T17 LOCAL CONFIG RESOLVER SELF TEST: PASS')
  console.log('T17 AUTH READINESS RETRY CONTRACT: PASS')
}

const selfTestMode=process.argv.includes('--self-test')
const waitForAuth=process.argv.includes('--wait-for-auth')

if(selfTestMode){
  await selfTest()
}else{
  const resolved=await discover({waitForAuth})
  process.stdout.write(JSON.stringify(resolved))
}
