End-of-day security review for this repository. Work read-only, then write a report. The only file you create is the report.

GROUND RULES
- Don't edit, commit, push, merge, stash, reset or switch branches. Don't install anything globally or run any "fix" or upgrade command.
- Don't deploy, restart, or write to any server, database or queue. Don't scan or probe hosts that aren't this project's.
- Never print a secret. Show its type, file:line and the first 4 characters only.
- Don't open or query real card numbers, CVVs, bank account numbers or SSNs. Review the code path instead.
- Don't post to Slack, email, Jira or anywhere else, and don't spend money.
- Work solo: no subagents or workflows. Read diffs; open whole files only when a diff needs context.
- Give every finding file:line evidence and label how you know it: READ (you read the code), RAN (you ran something and saw the result) or CONFIRMED (a person confirmed it). Never present READ as verified.
- Report real, reachable problems only. If you can't settle one, list it under "Couldn't settle". No generic hardening advice.

1. SCOPE TODAY'S WORK
- Run git fetch --all --prune. If it fails, say so and use local refs.
- List commits from the last 24 hours on every branch: git log --all --since="24 hours ago" --no-merges --stat. Add uncommitted and untracked changes in the working tree.
- If nothing changed, say so and skip to step 3 (run the audit only).

2. REVIEW EVERY CHANGED FILE FOR
- Secrets: keys, tokens, passwords, private keys, DB URLs with credentials, webhook URLs; .env or credential files added to git; .gitignore still excluding env files; secrets written to logs or returned by an API.
- Access control: every new or changed route, controller or handler requires login; it checks the caller owns the record (merchant, tenant or user scoping, no IDOR); admin and internal routes are protected; JWTs are verified (algorithm, expiry, no hardcoded secret); CORS is not *; login, OTP and password reset are rate-limited.
- Injection and input: SQL or Mongo queries built from input (including $where and operator injection), shell or exec calls, file paths from input, server-side fetches of user-supplied URLs (SSRF), unescaped HTML (innerHTML, dangerouslySetInnerHTML, v-html, Blade {!! !!}), file uploads (type, size, where stored), unsafe deserialization.
- Payments and personal data: card and bank data only pass through the gateway's tokenization and are never logged or stored; payment webhooks verify signatures; charges and refunds are idempotent; amounts keep one unit (cents or dollars) end to end; SSNs, birth dates, bank details, phones and emails stay out of logs and out of responses that don't need them.
- Config and deploy files (Dockerfile, docker-compose, nginx, pm2, deploy scripts, .env.example): databases, Redis or admin panels on 0.0.0.0 or public ports; debug mode on; TLS checks off (rejectUnauthorized: false, verify=False, CURLOPT_SSL_VERIFYPEER 0); chmod 777; default passwords.
- Mobile, if present: private keys or secrets in the app bundle, tokens outside secure storage, cleartext HTTP allowed, sensitive data in logs.
- AI features, if present: provider keys stay server-side; model output never runs as code or goes unescaped into SQL, HTML or a shell; user content can't make the model call privileged tools or read another customer's data.

3. DEPENDENCIES
- If a lockfile or manifest changed today, list each added or upgraded package. Flag any that is new to the project, rarely downloaded, published in the last few days, named like a typo of a popular package, or runs install scripts.
- Run the local audit for this stack (npm audit --omit=dev, composer audit, pip-audit, or the equivalent). Report only high and critical advisories in packages that ship to production.

4. YESTERDAY'S FINDINGS
- If ~/security-eod/[repo-name]/ holds an earlier report, re-check each open item against today's code and mark it FIXED (name the commit), STILL OPEN (re-checked today) or NOT RE-CHECKED. Never carry an item forward as open without checking it today.

5. WRITE THE REPORT
Save it to ~/security-eod/[repo-name]/[YYYY-MM-DD].md, outside the repo so it is never committed:
  # EOD security review: [repo-name], [date]
  Scope: branches, commit count, first..last SHA, uncommitted changes yes/no
  Verdict: CLEAN, or FINDINGS (n critical, n high, n medium, n low)
  Findings: severity | file:line | what's wrong | how someone would exploit it | fix | READ/RAN/CONFIRMED
  Yesterday's findings: status of each
  Dependencies: changes and advisories
  Couldn't settle / not checked

Severity:
- CRITICAL: exploitable now with real impact (a live secret in git history, unauthenticated access to customer data or money movement, card data logged).
- HIGH: easy to exploit, or exploitable after the next deploy.
- MEDIUM: needs unusual conditions or inside access.
- LOW: defense in depth. List five at most.

Then reply in chat with the verdict line, one line per CRITICAL or HIGH finding with its file:line, and the report path. For any CRITICAL, say what has to be rotated or switched off. Don't do the rotation yourself.
