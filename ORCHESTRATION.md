# Playpen Orchestration Research

Research into using Playpen containers as programmable, headless Claude Code instances controlled by an orchestrator.

## Concept

An orchestrator (Claude Code running normally on the host, or a script) spawns sandboxed Claude Code instances in Docker containers, sends them tasks, monitors progress, and collects results. Combined with a Ralph Wiggum loop, each container can iterate autonomously until a task is complete.

## Claude Code CLI Capabilities

### Headless Mode (`-p` flag)

Claude Code supports non-interactive execution:

```bash
claude -p "your prompt here"
```

Key flags:
- `-p, --print` : Run in non-interactive (headless) mode. Accepts a prompt, executes it, prints the result, and exits.
- `--output-format json` : Return structured JSON output instead of plain text.
- `--max-turns N` : Limit the number of agentic turns (tool calls) before stopping.
- `--max-budget-usd N` : Set a spending cap for the session.
- `--dangerously-skip-permissions` : Skip all permission prompts (already used in Playpen).

### Session Management

Claude Code has built-in session persistence:

- `--resume <session_id>` : Resume a specific previous session by ID.
- `--continue` : Continue the most recent session.
- Sessions are stored in `~/.claude/projects/` on the filesystem.

This means an orchestrator can:
1. Start a task with `-p "do X" --output-format json`
2. Check the result
3. Resume with `--resume <id> -p "now do Y"` for follow-up instructions

### Example: Headless Container Execution

```bash
docker run --rm \
  -v "$PROJECT_DIR":/workspace \
  -v ~/.claude.json:/root/.claude.json:ro \
  -w /workspace \
  playpen \
  -p "Run the test suite and fix any failing tests" \
  --output-format json \
  --max-turns 50
```

## Ralph Wiggum Integration

### What Ralph Wiggum Does

Ralph Wiggum is a Claude Code plugin/skill that implements a "keep going" loop. Instead of Claude stopping after completing a response, Ralph Wiggum:

1. **Intercepts the stop**: Uses a Stop hook that fires when Claude is about to exit
2. **Re-prompts**: Feeds the same (or a modified) prompt back to Claude
3. **Checks for completion**: Looks for a "completion promise" in Claude's output (a signal that the task is truly done)
4. **Enforces limits**: Stops after N iterations or when the completion promise is detected

### State Management

Ralph Wiggum uses a state file (`.claude/ralph-loop.local.md`) to track:
- Current iteration count
- Maximum iterations allowed
- The original prompt/goal
- Whether a completion promise has been detected

### Integration with Playpen

For container-based Ralph Wiggum loops:

**Option A: Ralph Wiggum inside the container**
- Install the Ralph Wiggum skill/hook in the Docker image
- The container runs autonomously, looping until done
- Orchestrator just monitors the container status

**Option B: External loop (orchestrator-driven)**
- Orchestrator runs `docker run ... playpen -p "task" --output-format json`
- Checks the JSON output for completion signals
- If not done, runs another `docker run` with `--continue` or `--resume`
- More control but more overhead per iteration

Option B is more flexible and doesn't require modifying the Docker image.

## Architecture

### Phase 1: Bash + CLI (Simple)

A bash script that orchestrates multiple containers:

```bash
#!/bin/bash
# orchestrate.sh - Run a task in a Playpen container with retry loop

PROJECT_DIR="$1"
TASK="$2"
MAX_ITERATIONS="${3:-5}"

for i in $(seq 1 $MAX_ITERATIONS); do
    echo "Iteration $i/$MAX_ITERATIONS"

    RESULT=$(docker run --rm \
        -v "$PROJECT_DIR":/workspace \
        -v ~/.claude.json:/root/.claude.json:ro \
        -w /workspace \
        playpen \
        -p "$TASK" \
        --output-format json \
        --max-turns 30 2>&1)

    # Check if task signals completion
    if echo "$RESULT" | jq -e '.result' | grep -q "TASK_COMPLETE"; then
        echo "Task completed on iteration $i"
        exit 0
    fi

    # Update task for next iteration
    TASK="Continue working on the previous task. Review what was done and finish any remaining work."
done

echo "Reached max iterations ($MAX_ITERATIONS)"
```

### Phase 2: Agent SDK (Advanced)

For more sophisticated orchestration, use the Anthropic Agent SDK to build a proper orchestrator:

- Spawn multiple containers in parallel for independent tasks
- Route results between containers (output of one feeds into another)
- Implement proper error handling and retry logic
- Add monitoring dashboards and cost tracking
- Use structured tool definitions for container management

## Monitoring

### Container Status

```bash
# List running Playpen containers
docker ps --filter "name=playpen-*"

# Follow logs from a container
docker logs -f playpen-my-project

# Kill a runaway container
docker kill playpen-my-project
```

### Cost Tracking

Use `--max-budget-usd` to cap spending per container. The orchestrator can aggregate costs across all spawned containers.

### Output Collection

When using `--output-format json`, the output includes:
- The final response text
- Token usage (input/output)
- Tool calls made
- Session ID for resumption

## Use Cases

1. **Parallel test fixing**: Spawn one container per failing test file. Each container focuses on fixing its assigned tests.

2. **Code review + fix**: One container reviews code, outputs findings. Orchestrator spawns fix containers for each finding.

3. **Bulk refactoring**: Split a large refactor across multiple containers, each handling a different module.

4. **CI/CD integration**: Run Playpen containers in CI to auto-fix linting errors, update dependencies, or generate boilerplate.

## Limitations

- **No MCP servers**: Containers don't have access to MCP servers (no Playwright, no Supabase, etc.)
- **No session sharing**: Each container has its own session state. Containers can't directly communicate.
- **Cold start**: Each `docker run` starts a fresh Node.js process. There's a few seconds of startup overhead.
- **Memory**: Colima VM has 4GB RAM. Running many containers simultaneously may hit memory limits. Increase with `colima stop && colima start --memory 8`.

## Next Steps

1. Build a simple orchestrate.sh script (Phase 1) and test with a real project
2. Define a completion signal protocol (how Claude signals "I'm done" vs "I need more iterations")
3. Experiment with `--resume` for multi-turn orchestration without Ralph Wiggum
4. Evaluate whether Ralph Wiggum should run inside or outside the container
5. Prototype Phase 2 with the Agent SDK if Phase 1 proves the concept
