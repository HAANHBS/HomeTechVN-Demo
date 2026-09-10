import { spawnSync } from 'node:child_process'
import path from 'node:path'
const root=process.cwd()
function run(cmd,args){const r=spawnSync(cmd,args,{cwd:root,stdio:'inherit',shell:false});if(r.error){console.error(r.error.message);process.exit(1)}if(r.status!==0)process.exit(r.status??1)}
run(process.execPath,[path.join('scripts','t17-powershell-static-check.mjs')])
run(process.execPath,[path.join('scripts','t17-resolve-local-config.mjs'),'--self-test'])
run(process.execPath,[path.join('scripts','t17-demo-load.mjs'),'--self-test'])
run(process.execPath,[path.join('scripts','t17-source-check.mjs')])
run('powershell.exe',['-NoProfile','-ExecutionPolicy','Bypass','-File',path.join(root,'scripts','t17-verify.ps1')])
