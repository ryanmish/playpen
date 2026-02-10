# Playpen Security Audit

Threat model and security assessment for the Playpen sandboxed Claude Code environment.

## Scope

This audit focuses on **container escape and host compromise** vectors. Arbitrary code execution inside the container is expected and accepted (that's the point of `--dangerously-skip-permissions`). The concern is whether code running inside the container can reach out and affect the host machine or external systems.

## Threat Model

**Attacker**: Malicious or confused AI-generated code running inside the container with root privileges.

**Goal**: Access host filesystem, exfiltrate credentials, or affect systems beyond the mounted project folder.

## Findings

### CRITICAL

#### 1. SSH Keys Accessible (Mounted Read-Only)

`~/.ssh/` is mounted at `/root/.ssh/:ro` inside the container. While read-only prevents modification, the private keys are fully readable. Code inside the container can:

- Read private keys and use them for SSH connections
- Push to any git repository the keys have access to
- Connect to any server the keys authenticate to
- Exfiltrate the keys themselves over the network

**Mitigation**: Remove the `~/.ssh` mount. Use deploy keys per-project or a git credential helper that doesn't expose raw keys. Alternatively, use `--network=none` to prevent any network access.

#### 2. OAuth Tokens Exposed

`~/.claude.json` is mounted read-only but contains OAuth tokens. Code can read these tokens and potentially:

- Make API calls to Anthropic as the authenticated user
- Access any service the OAuth tokens grant access to

**Mitigation**: Create a minimal config file with only the necessary auth fields instead of mounting the entire `~/.claude.json`. Or use a dedicated API key (`ANTHROPIC_API_KEY`) with spending limits instead of OAuth.

#### 3. No Network Isolation

The container has full unrestricted network access via Colima's NAT networking. This means code can:

- Send data to any external server (exfiltration)
- Download and execute additional payloads
- Make API calls to external services
- Scan the local network

**Mitigation**: Add `--network=none` to the Docker run arguments. This completely disables networking. Projects that need internet (npm install, git push) would need a separate network mode or a pre-build step.

#### 4. Combined Exfiltration Scenario

The combination of readable SSH keys + readable OAuth tokens + unrestricted network creates a worst-case scenario: code can steal credentials and immediately send them to an external server. Each finding alone is concerning; together they form a complete exfiltration chain.

**Mitigation**: Address all three findings above. The most impactful single fix is `--network=none`.

### HIGH

#### 5. Git Config Exposure

`~/.gitconfig` is mounted read-only. While less sensitive than SSH keys, it may contain:

- Email addresses
- Signing key references
- Credential helper configurations
- Proxy settings revealing internal network topology

**Mitigation**: Create a minimal `.gitconfig` with only name and email for commits, mounted instead of the full config.

#### 6. Project Folder is Read-Write

The mounted project folder has full read-write access. Malicious code could:

- Delete or corrupt project files
- Inject malicious code into the project (which then gets committed/pushed)
- Modify `.git/hooks` to execute code on the host when git operations are run later

**Mitigation**: This is somewhat by design (Claude needs to edit files). Git provides the safety net here: review changes via `git diff` before committing. Consider mounting as read-only for review-only sessions.

### MEDIUM

#### 7. Container Runs as Root

The container runs all processes as root. While this doesn't directly affect the host (Docker's namespace isolation prevents root-on-container from being root-on-host), it means:

- No defense-in-depth inside the container
- If a Docker escape vulnerability exists, it would grant host root access

**Mitigation**: Add a non-root user to the Dockerfile and run Claude Code as that user. This provides defense-in-depth without affecting functionality.

#### 8. Docker Socket Not Mounted (Good)

The Docker socket (`/var/run/docker.sock`) is NOT mounted into the container. This is correct. Mounting the Docker socket would allow container escape by creating sibling containers with host filesystem access.

**Status**: Not vulnerable. No action needed.

### LOW

#### 9. Image Pinning

The Dockerfile uses `node:22-slim` without a specific digest. A supply chain attack on the Node.js Docker image could inject malicious code.

**Mitigation**: Pin the image to a specific digest: `node:22-slim@sha256:<hash>`. Update periodically.

### NOT VULNERABLE

- **Host filesystem access**: Only the explicitly mounted paths are accessible. The container cannot see or access other host directories.
- **Docker escape via socket**: Docker socket is not mounted.
- **Colima VM escape**: Colima uses Lima which runs a full Linux VM. Code would need to escape both the Docker container and the VM to reach the host.

## Hardening Recommendations (Priority Order)

1. **Add `--network=none`** to Docker run args for maximum isolation. This single change eliminates the exfiltration chain. Add a `--online` flag to the launcher for when internet access is genuinely needed.

2. **Remove `~/.ssh` mount** by default. Add a `--git-push` flag that mounts SSH keys only when the user explicitly needs push access.

3. **Use a dedicated API key** with spending limits instead of mounting the full `~/.claude.json` OAuth config.

4. **Create a non-root user** in the Dockerfile for defense-in-depth.

5. **Pin the base image** to a specific digest.

## Risk Summary

| Finding | Severity | Status |
|---------|----------|--------|
| SSH keys readable | CRITICAL | **Fixed** (mount removed) |
| OAuth tokens exposed | CRITICAL | Open (network required for API calls) |
| No network isolation | CRITICAL | Accepted (network required for API calls) |
| Combined exfiltration | CRITICAL | Mitigated (SSH removed, but OAuth + network remains) |
| Git config exposure | HIGH | Open |
| Project folder read-write | HIGH | Accepted (by design) |
| Container runs as root | MEDIUM | Open |
| Docker socket not mounted | N/A | Not vulnerable |
| Image not pinned | LOW | Open |

## Conclusion

The setup provides **filesystem isolation** (container can only access mounted paths). SSH keys are no longer mounted, eliminating the most critical credential exposure. Network access cannot be disabled because Claude Code requires API connectivity to function.

The remaining risk is OAuth token exfiltration over the network. For maximum security, consider using a dedicated API key (`ANTHROPIC_API_KEY`) with spending limits instead of mounting the full OAuth config.
