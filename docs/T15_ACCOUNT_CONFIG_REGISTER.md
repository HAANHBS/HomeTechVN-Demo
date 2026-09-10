# T15 Account / Config Register

- Environment: DEV / backup candidate
- Supabase project: HomeTechVN
- Project ref: `puqvbenyenwemfbsqpfd`
- Supabase plan: Free
- Region: Singapore (`ap-southeast-1`)
- PostgreSQL: 17.6
- Remote database size at preflight: approximately 18 MB
- Remote Storage buckets at preflight: 0
- Remote Storage objects at preflight: 0
- Implementation date: 31/08/2026
- Responsible person: HomeTechVN project owner
- Backup tool: Supabase CLI 2.116.0 baseline
- Database connection mode for production backup: Session pooler
- Backup secret store:
  `%LOCALAPPDATA%\HomeTechVN\Backup\secrets.json`
- Secret protection: Windows DPAPI / current Windows user
- Non-secret backup config:
  `%LOCALAPPDATA%\HomeTechVN\Backup\config.json`
- Default backup output recommendation: `D:\HOMETECHVN_BACKUPS`
- Default retention: 30 days
- Default schedule recommendation: daily 02:15
- Storage backup at initial T15 acceptance: not required while remote object count = 0
- Future Storage tool: rclone via Supabase S3 endpoint
- Source secret inclusion: prohibited
- New database migration: none
- New application secret: none
- Real production backup: PASS — `D:\HOMETECHVN_BACKUPS\HomeTechVN_20260831_171756`
- Restore drill: PASS — `D:\HOMETECHVN\docs\snapshots\T15_LOCAL_VERIFY_20260831_172248.txt`
- Error notes: none yet
