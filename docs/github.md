# Putting Korram on GitHub

The repo has never been pushed anywhere: it has no remote yet. This guide covers the decisions
to make first, the push itself, and what to set up afterwards.

**Already checked (2026-10-21):**
- **What goes up:** 590 tracked files, about 11 MB of history.
- **Largest files:** the design file (4.6 MB) and the PRD PDF (0.6 MB), both well under
  GitHub's 100 MB limit.
- **No real secrets anywhere in the history.**
  - `infra/.env` is ignored.
  - `infra/.env.example` and `backend/korram/settings/test.py` hold only clearly labelled
    dev and test values (`dev-only-insecure-…`, `korram-dev-secret`).
  - The scan looked for cloud keys, private keys, service-account JSON and tokens.
- **CI runs clean:** every step in `.github/workflows/ci.yml` passes locally with the same
  tool versions CI uses (Flutter 3.32.0, uv 0.10.10, Node 22), so the first push should be
  green.

---

## 1. Decide first

### Private or public? Recommendation: **private**

The repo contains:
- the full PRD, including the business model
- the design file
- the moderation and safety design (thresholds, how the agent works)
- the open legal questions in `docs/questions.md`

None of that should be public before launch. A private repo costs nothing on a personal
GitHub account. Make it public later if you want to, after a fresh review.

### Which email the commits show

All 13 commits are authored by `Jonah Onah <onahjonah@gmail.com>`. GitHub shows that address
on every commit page, to everyone who can see the repo.

- **If the repo stays private and that's fine with you:** nothing to do.
- **If you'd rather hide it:**
  1. In GitHub, go to Settings → Emails and tick **Keep my email addresses private**. GitHub
     shows your no-reply address, for example `12345678+yourname@users.noreply.github.com`.
  2. Use it for this repo and rewrite the 13 commits before the first push (safe now, because
     nothing has been pushed yet):

     ```sh
     cd ~/Desktop/korram
     git config user.email "12345678+yourname@users.noreply.github.com"
     git rebase --root --exec 'git commit --amend --no-edit --reset-author'
     git log --format='%h %an <%ae>' | head -3   # check
     ```

     After the first push, don't rewrite history again: it breaks everyone else's copy.

### Repo name and owner

The suggested name is `korram`, under your account or a GitHub organisation if you'll have a
team. An organisation makes it easier to add people and move ownership later.

---

## 2. Create the repo and push

### Option A — GitHub CLI (fewest steps)

```sh
brew install gh
gh auth login                      # GitHub.com → HTTPS → log in with a browser
cd ~/Desktop/korram
gh repo create korram --private --source=. --remote=origin --push
```

That creates the repo, adds it as `origin`, and pushes `main`.

### Option B — the website

1. Go to https://github.com/new.
2. Name it `korram` and choose **Private**.
3. **Don't** add a README, .gitignore or licence. The repo already has them, and an extra
   first commit on GitHub makes the push get rejected.
4. Push from the terminal:

   ```sh
   cd ~/Desktop/korram
   git remote add origin https://github.com/<you>/korram.git
   git push -u origin main
   ```

   When asked for a password, use a **personal access token**, not your GitHub password:
   - Create it at Settings → Developer settings → Fine-grained tokens.
   - Scope it to this repo, with "Contents: Read and write".
   - Or run `gh auth login` once (Option A), and git will use it from then on.

### Check it worked

- The repo page shows the README and 13 commits (14 with this guide).
- The **Actions** tab shows a "CI" run with three jobs: `backend`, `app`, `admin`. All three
  should go green in about 5–8 minutes.

---

## 3. What CI checks (and what it doesn't)

| Job | Runs |
|---|---|
| `backend` | `ruff` lint and format, migrations up to date, `pytest` on Postgres 16 + Redis 7, and the OpenAPI schema matching the app's generated client |
| `app` | `dart format`, `flutter analyze`, `flutter test` (not goldens, not e2e) |
| `admin` | `eslint`, Vitest, production build |

**Not in CI,** so run them yourself before merging changes that touch them:
- **Golden images:** they're rendered on macOS, and Linux draws text slightly differently.
  Run `cd app && flutter test --tags golden`.
- **End-to-end tests:** they need the running stack.

  ```sh
  make up
  make test-e2e
  ```

- **Call and moderation harness:** run `make test-calls` (needs the stack).
- **Matching load test:** see "Matching load test" in the README.

---

## 4. After the first push (recommended)

1. **Protect `main`** (Settings → Branches → Add rule for `main`):
   - Require a pull request before merging.
   - Require status checks to pass: `backend`, `app`, `admin`.
   - Block force pushes.
2. **Turn on secret scanning and push protection** (Settings → Code security). GitHub then
   refuses pushes that contain real keys.
3. **Dependabot alerts** (same page): warnings for vulnerable dependencies. They're
   warnings only, no automatic changes.
4. **Add people** (Settings → Collaborators): give developers "Write" and others "Read".

---

## 5. Keys that must never be committed

These arrive with the open questions. Put them in `infra/.env` locally (ignored) and in your
hosting provider's secret store for production. If CI ever needs one, add it as a GitHub
Actions secret (Settings → Secrets and variables → Actions).

| What | Where it goes | Questions |
|---|---|---|
| Firebase service-account JSON (push) | `FCM_CREDENTIALS_JSON` | #31 |
| Google Play service account (purchases) | `PLAY_CREDENTIALS_JSON`, `PLAY_RTDN_SECRET` | #35 |
| Apple In-App Purchase key and root certificates | `APPLE_*` settings / `APPLE_ROOT_CERTS_DIR` | #35 |
| Real `DJANGO_SECRET_KEY`, database and S3 passwords, LiveKit keys | production environment only | — |
| Android release signing keystore (`*.jks`) and its passwords | a password manager, plus your CI secret store when releases are built in CI | — |

`google-services.json` and `GoogleService-Info.plist` (Firebase app config) aren't secret,
but they tie builds to your Firebase project. Keep them out of the repo too, and copy them in
at build time.

If a real key is ever pushed by mistake, **rotate it first**. Deleting the commit doesn't
help: anyone who saw the repo may already have it.

---

## 6. Day-to-day workflow

```sh
git switch -c m8-thing          # one branch per piece of work
# ... commit as you go ...
git push -u origin m8-thing
gh pr create --fill             # or open a pull request on the website
```

- **Commit messages** name the requirement IDs (FR-, SF-, MN-), as in the existing history
  (CLAUDE.md).
- **Before merging:** CI is green, and goldens and e2e have been run locally if the change
  touches the UI or the API.
- **After an API change:** run `make api-client` and commit the regenerated client. CI fails
  if the schema and the client differ.

---

## Troubleshooting

| Message | Cause and fix |
|---|---|
| `! [rejected] main -> main (fetch first)` | The GitHub repo was created with a README or licence. Delete and recreate it empty, or run `git pull --rebase origin main` and push again. |
| `Authentication failed` / `Password authentication is not supported` | Use a personal access token or `gh auth login`, not your account password. |
| `remote: Permission to … denied` | The token can't write to this repo. Give it "Contents: Read and write" for `korram`. |
| `GH013: Repository rule violations … secret detected` | Push protection found a key. Remove it from the commit, rotate the key, and push again. |
| CI `app` job fails on goldens | It shouldn't run them (`--exclude-tags golden`). Check that `dart_test.yaml` still declares the `golden` and `e2e` tags. |
