# HomeTechVN T18 v1.3 — PowerShell required-entry array correction

## Windows failure

The v1.2 release ZIP was created, but its post-package verification reported
all five required paths as one missing entry.

## Root cause

The PowerShell array used comma-terminated prefix concatenations:

```powershell
$prefix + 'package.json',
$prefix + 'app/package.json',
```

Under Windows PowerShell 5.1, the comma operator bound inside the addition
expression. The loop therefore received one nested array and string
interpolation rendered all five paths separated by spaces. The ZIP entries
themselves were not shown to be absent.

## Correction

The packager now keeps five plain relative-path strings, one per line and with
no commas. The loop combines exactly one relative path with the prefix before
performing membership testing.

Both `t18-source-check.mjs` and `t18-package-policy-self-test.mjs` reject the old
comma-expression form and verify the exact five-item required-entry contract.
The global PowerShell static checker now rejects comma-terminated variable
concatenation across every managed `.ps1` file, so the same construct cannot
move to another verifier unnoticed.
No application, Worker, migration, environment, or database behavior changed.
