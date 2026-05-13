# olho-kreuzberg Governance

## Fork Structure

```
olho-kreuzberg/
├── main                    ← Mirrors upstream kreuzberg-dev/kreuzberg:main
├── patched/main            ← Fork patches live here (current branch)
└── Dockerfile.kreuzberg    ← Fork-specific Dockerfile (untracked)
```

### Branch Conventions

| Branch | Purpose | Push Target |
|--------|---------|-------------|
| `main` | Mirrors upstream `kreuzberg-dev/kreuzberg:main` | `origin/main` |
| `patched/main` | Fork patches on top of upstream `main` | `origin/patched/main` |

### Remote Configuration

```
origin  git@github.com:oleksii-honchar/kreuzberg.git
```

No `upstream` remote is configured yet — upstream is `kreuzberg-dev/kreuzberg`.

---

## Upstream Sync Procedure

### Normal Sync (No Conflicts)

```bash
# 1. Fetch upstream
git fetch origin

# 2. Rebase patched/main onto upstream main
git checkout patched/main
git rebase origin/main

# 3. Force-push (safe since we're rebasing our own branch)
git push --force-with-lease origin patched/main
```

### Sync with Conflicts

```bash
# 1. Start rebase
git checkout patched/main
git rebase origin/main

# 2. Resolve conflicts in fork-specific files
#    - handlers.rs
#    - env.rs
#    - Dockerfile.kreuzberg

# 3. Continue rebase
git add <resolved-files>
git rebase --continue

# 4. Force-push
git push --force-with-lease origin patched/main
```

---

## Feature Branch Workflow

For adding new patches:

```bash
# 1. Start from patched/main
git checkout patched/main
git checkout -b feature/my-new-patch

# 2. Make changes
#    ...

# 3. Commit
git add -A
git commit -m "feat: add my new patch"

# 4. Test
cargo test

# 5. Rebase onto patched/main (if it moved)
git rebase patched/main

# 6. Merge back
git checkout patched/main
git merge --no-ff feature/my-new-patch
```

---

## Build and Verification

```bash
# Full build
cargo build --release

# Run tests
cargo test

# Build Docker image
docker build -f Dockerfile.kreuzberg -t olho-kreuzberg .

# Run Docker image
docker run --rm -it -p 3000:3000 olho-kreuzberg
```

---

## Push Procedures

```bash
# Push patched/main (after rebase/sync)
git push --force-with-lease origin patched/main

# Push feature branch
git push origin feature/my-new-patch
```

**Force-push safety:** Always use `--force-with-lease` — it fails if the remote has new commits you don't have locally.

---

## Recovery Scenarios

### Accidentally force-pushed wrong branch

```bash
# Reset to last known good commit
git reset --hard <good-commit-sha>
git push --force-with-lease origin patched/main
```

### Lost work after rebase

```bash
# Check reflog
git reflog

# Reset to before the bad rebase
git reset --hard HEAD@{1}
```

---

## Common Mistakes to Avoid

1. **Don't merge upstream into `patched/main`** — Use `rebase`, not `merge`, to keep history linear.
2. **Don't commit directly to `main`** — `main` should mirror upstream exactly.
3. **Don't forget `--force-with-lease`** — Always use it when pushing rebased branches.
4. **Don't skip tests** — Always run `cargo test` before pushing.
