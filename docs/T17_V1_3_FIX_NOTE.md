# HomeTechVN — T17 v1.3 FIX NOTE

Date: 31/08/2026

## Windows v1.2 finding

The loader reached the local API URL fallback and then failed inside .NET Regex:

```text
Exception calling "Match" with "2" argument(s):
parsing "(?ms)^\\s*\\[api\\]\\s*(.*?)(?=^\\s*\\[|\\z)"
- Unterminated [] set.
```

## Root cause

The PowerShell source contained regex escapes that were escaped twice.

Incorrect PowerShell/.NET regex:

```text
\\s*\\[api\\]
```

Correct regex:

```text
\s*\[api\]
```

PowerShell single-quoted strings do not require backslashes to be doubled for
.NET regular-expression syntax.

## v1.3 correction

The loader now uses:

```powershell
'(?ms)^\s*\[api\]\s*(.*?)(?=^\s*\[|\z)'
'(?m)^\s*port\s*=\s*(\d+)\s*$'
```

and the ordinary-status parsing regexes were normalized the same way.

The T17 source checker now explicitly rejects recurrence of the double-escaped
`[api]` / `port` regexes.

## Database impact

None.

```text
T1 → T16 = 36 migrations unchanged
T17 DB migration = 0
```
