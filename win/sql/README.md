# SQL Server Snippets — source layout

This directory is the source of truth for the Windows Toolkit's **SQL Server
Snippets** module. It is not a PowerShell module you run directly; the build
embeds its contents into the toolkit.

```
win/sql/
├── snippets.ps1          # registry: metadata for every snippet
├── users/                # Users & Security
├── health/               # Database Health
├── performance/          # Performance
├── maintenance/          # Maintenance
├── connections/          # Connections & Sessions
└── troubleshooting/      # Troubleshooting
```

Each snippet is a pair:

1. **A `.sql` file** — the T-SQL text, with `{{Name}}` tokens for parameters.
2. **A registry entry** in `snippets.ps1` — metadata plus the `.sql` path.

The build (`tests/Sync-SqlSnippets.ps1`) validates both, then generates the
`Get-PcSqlSnippetRegistry` function inside `win/modules/Sql-Snippets.ps1`.
Nothing is downloaded at runtime and no SQL is ever executed or connected.

## Adding a snippet

1. Create `win/sql/<category>/<id>.sql` with the T-SQL. Use `{{Name}}` for any
   value you want the user to fill in, for example `USE {{Database}};`. The
   token is written bare; the parameter's `Kind` decides how it is rendered
   and validated (bracketed, N-quoted, numeric, or allowlisted).

2. Add one entry to `win/sql/snippets.ps1`:

   ```powershell
   [pscustomobject]@{
       Id          = 'my-snippet'            # lowercase-kebab, matches the filename
       Title       = 'My snippet title'
       Category    = 'health'                # users|health|performance|maintenance|connections|troubleshooting
       Description = 'One-line purpose.'
       Type        = 'READ-ONLY'             # or 'MODIFICATION'
       Scope       = 'Database'
       Permissions = 'VIEW DATABASE STATE'
       Compatibility = 'SQL Server 2016-2025'
       Cost        = 'Light'                 # Light|Moderate|Heavy
       Docs        = 'https://learn.microsoft.com/...'   # optional
       Parameters  = @( @{ Name='Database'; Default='YourDatabase'; Kind='Identifier' } )
       SqlFile     = 'health/my-snippet.sql'
   }
   ```

3. Run `pwsh -NoProfile -File ./tests/Sync-SqlSnippets.ps1` (or the full
   `./tests/Sync-Site.ps1`). The build rejects duplicate ids, unknown
   categories/types, mismatched or escaping SQL paths, unregistered SQL files,
   malformed `{{token}}` placeholders, undeclared parameters, and missing
   operational metadata.

4. Extend `tests/Test-SqlSnippets.ps1` if the new snippet changes counts or
   behavior the suite asserts on.

## Parameters

`Parameters` is an array of `@{ Name; Default; Kind }`:

| Kind | Renders as | Use for |
| --- | --- | --- |
| `Identifier` (default) | `[value]` with `]` escaped as `]]` | databases, users, logins, tables |
| `Literal` | `N'value'` with `'` doubled | string values in predicates |
| `Integer` | validated whole number | counts, minutes, days; supports `Min`/`Max` |
| `Decimal` | invariant-culture decimal | ratios and percentages; supports `Min`/`Max` |
| `Enum` | one value from `AllowedValues` | SQL keywords or other predefined choices |

Every `{{Name}}` in the SQL must have a matching parameter and vice versa.
Snippets with no parameters omit the field and the SQL contains no `{{...}}`.
Free-form raw substitution is intentionally unsupported.

## Conventions

- Prefer modern, supported catalog views and DMVs (`sys.database_principals`,
  `sys.dm_exec_requests`, ...) over deprecated `sys.sysusers`/`sp_*` checks.
- Prefix database-scoped queries with `USE [{{Database}}];` and mark
  server-scoped queries with a `-- Server-scoped:` comment so no one assumes
  the current database is `master`.
- Never assume database user names match server login names; join on `sid`.
- `MODIFICATION` snippets must not auto-repair or risk data loss. `DBCC CHECKDB`
  is read-only here (no `REPAIR_*`) and is labelled resource-intensive.
- Use official Microsoft Learn pages for `Docs`.
