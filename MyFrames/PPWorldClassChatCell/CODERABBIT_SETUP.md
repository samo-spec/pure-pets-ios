# CodeRabbit CLI setup on macOS

## 1. Confirm DNS and HTTPS access

```bash
dscacheutil -q host -a name cli.coderabbit.ai
curl -I https://cli.coderabbit.ai/install.sh
```

If `curl` reports `Could not resolve host`, the problem is DNS/network access, not the install command. Try these in order:

```bash
sudo dscacheutil -flushcache
sudo killall -HUP mDNSResponder
```

Then retry the two checks. Also inspect stale proxy variables:

```bash
env | grep -i proxy
```

Only when an old or incorrect proxy is shown, clear it for the current terminal:

```bash
unset HTTP_PROXY HTTPS_PROXY ALL_PROXY http_proxy https_proxy all_proxy
```

If DNS still fails, try a different network or phone hotspot before changing more system settings.

## 2. Install the official CLI

```bash
curl -fsSL https://cli.coderabbit.ai/install.sh | sh
source ~/.zshrc
coderabbit --version
```

`cr` and `coderabbit` are equivalent commands.

## 3. Authenticate

Human-readable flow:

```bash
coderabbit auth login
coderabbit auth status
```

Agent/structured flow:

```bash
coderabbit auth login --agent
coderabbit auth status --agent
```

The login command opens a browser for authorization.

## 4. Run inside a Git repository

```bash
cd /path/to/your/project
git rev-parse --is-inside-work-tree
```

If this is a new local project that is not yet a repository:

```bash
git init
git add .
git commit -m "chore: baseline before chat cell upgrade"
```

## 5. Review

Human-readable review:

```bash
coderabbit review --plain -t uncommitted
```

Agent review:

```bash
coderabbit review --agent -t uncommitted
```

Compare with another base branch when required:

```bash
coderabbit review --agent --base develop
```

## 6. Optional Codex integration

Inside Codex, open `/plugins`, search for `coderabbit`, install it, then restart/reload Codex. You can then ask:

```text
@coderabbit Review my current uncommitted changes. Fix critical and major issues, run tests, and perform one final review pass.
```

The standalone skills package can also be installed with:

```bash
npx skills add coderabbitai/skills -g
```
