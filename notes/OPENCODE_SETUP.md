# OpenCode Advanced Configuration Guide

This project is configured with an advanced OpenCode setup that closely mirrors Claude Code's capabilities with reasoning, planning, thinking, and specialized agents.

## Configuration Overview

Your `opencode.json` is now configured with:

### Multi-Agent System

OpenCode now runs with **6 specialized agents**, each optimized for different tasks:

#### Primary Agents (accessible via Tab key)

1. **Build Agent** (Default)
   - Full development capabilities with all tools enabled
   - Temperature: 0.7 for balanced creativity
   - Max Steps: 50
   - All permissions require approval (ask mode)
   - **Use for**: General development, implementing features, writing code

2. **Plan Agent**
   - Read-only analysis and strategic planning
   - Temperature: 0.2 for focused reasoning
   - Max Steps: 30
   - No file modifications or bash execution
   - **Use for**: Architecture planning, code analysis, design decisions

3. **Review Agent**
   - Code review and suggestions
   - Temperature: 0.3 for precise analysis
   - Max Steps: 25
   - Read-only with documentation capabilities
   - **Use for**: Code reviews, quality checks, best practices

4. **Debug Agent**
   - Investigation and debugging
   - Temperature: 0.4 for systematic analysis
   - Max Steps: 40
   - Bash enabled for diagnostics (with approval)
   - **Use for**: Bug hunting, performance analysis, troubleshooting

5. **General Agent**
   - Multi-step research and complex tasks
   - Temperature: 0.6 for versatility
   - Max Steps: 50
   - **Use for**: Research, documentation, complex multi-step workflows

6. **Explore Agent**
   - Fast codebase exploration
   - Uses lighter Qwen 7B model for speed
   - Temperature: 0.3
   - Max Steps: 20
   - Read-only, optimized for searching
   - **Use for**: Finding files, searching code patterns, codebase navigation

### Model Configuration

- **Primary Model**: Qwen2.5-Coder-32B (SOTA dual GPU model)
- **Small Model**: Nemotron Mini 4B (for lightweight tasks like titles)
- **Explore Agent**: Qwen2.5-Coder-7B (optimized for speed)

All models configured with appropriate temperatures for their tasks.

### Tool System

All 13 built-in tools are configured:
- `read`, `write`, `edit` - File operations
- `bash` - Shell command execution
- `grep`, `glob`, `list` - Search and navigation
- `patch` - Apply code patches
- `webfetch` - Web content retrieval
- `todowrite`, `todoread` - Task management
- `skill` - Skill file loading
- `lsp` - Language Server Protocol (disabled by default, can enable)

### Permission System

Granular control over operations:
- **Edit/Write/Bash**: Require approval (`ask`)
- **Webfetch**: Auto-approved (`allow`)
- **External Directory**: Require approval (`ask`)

Per-agent permissions override global settings for specialized workflows.

## Usage Examples

### Switch Between Agents

```bash
# Press Tab key to cycle through primary agents
# Or use @ mentions to invoke specific agents:
opencode
> @plan analyze the authentication system
> @explore find all API endpoints
> @review check this component for issues
> @debug investigate the memory leak
```

### Agent-Specific Workflows

**Planning Session:**
```bash
# Start with plan agent for architecture
opencode --agent plan
> Design a microservices architecture for this monolith

# Plan agent will analyze without modifying files
# Then switch to build agent to implement
```

**Code Review:**
```bash
opencode --agent review
> Review the changes in src/auth/login.ts

# Get detailed analysis without modifications
```

**Fast Exploration:**
```bash
opencode --agent explore
> Find all files that handle user authentication

# Uses lightweight model for quick searches
```

**Debugging:**
```bash
opencode --agent debug
> Investigate why the tests are failing

# Can run diagnostics commands with approval
```

## Model Switching

Use the Makefile targets to switch between different models:

### Small Models (Nvidia GPU - CUDA)
```bash
make use-nemotron       # 4B - Fast, low latency
make use-qwen           # 7B - Balanced
```

### Large Models (Intel GPU - Vulkan)
```bash
make use-nemotron-nano      # 30B MoE - Reasoning
make use-deepseek-dualgpu   # 16B - SOTA, lighter
make use-qwen32b-dualgpu    # 32B - SOTA coding (Recommended)
```

When you switch models, update the `model` field in `opencode.json` to match.

## Advanced Features

### Custom Instructions
Add project-specific guidelines by creating instruction files:

```json
{
  "instructions": [
    ".opencode/instructions.md",
    "docs/coding-standards.md"
  ]
}
```

### MCP Server Integration
Connect external tools and databases:

```json
{
  "mcp": {
    "servers": {
      "postgres": {
        "command": "npx",
        "args": ["-y", "@modelcontextprotocol/server-postgres"],
        "env": {
          "DATABASE_URL": "{env:DATABASE_URL}"
        }
      }
    }
  }
}
```

### LSP Support (Experimental)
Enable code intelligence features:

1. Set environment variable:
   ```bash
   export OPENCODE_EXPERIMENTAL_LSP_TOOL=true
   ```

2. Enable in config:
   ```json
   {
     "tools": {
       "lsp": true
     }
   }
   ```

3. LSP servers are auto-detected based on your development environment

### Custom Commands
Create reusable task templates:

```json
{
  "command": {
    "test-coverage": {
      "template": "Run the test suite with coverage and fix any failing tests",
      "description": "Run tests with coverage",
      "agent": "build"
    },
    "performance-audit": {
      "template": "Analyze the application for performance bottlenecks",
      "description": "Performance analysis",
      "agent": "debug"
    }
  }
}
```

Usage: `opencode test-coverage`

## Configuration Management

This project uses **GNU Stow** to manage the OpenCode configuration. The configuration files are stored in:
- `config/.config/opencode/opencode.json` (source)
- `~/.config/opencode/` (symlinked to source)

### Managing Configuration

```bash
# Install/sync configuration (uses stow)
make config-install

# Check configuration status
make config-status

# Edit configuration (opens in $EDITOR)
make config-edit

# Remove configuration symlinks
make config-uninstall
```

Changes made to files in `config/.config/opencode/` are automatically reflected in `~/.config/opencode/` due to symlinking.

## Configuration Hierarchy

OpenCode merges configurations in this order (later overrides earlier):

1. Global: `~/.config/opencode/opencode.json` (managed by this project via stow)
2. Project: `./opencode.json` (not used - we use global config)
3. Agent-specific: `.opencode/agent/*.md` or JSON definitions

## Comparison with Claude Code

This configuration now provides Claude Code-like capabilities:

| Feature | Claude Code | OpenCode (This Config) |
|---------|-------------|------------------------|
| Planning Mode | ✅ | ✅ (Plan Agent) |
| Reasoning | ✅ | ✅ (Temperature-controlled) |
| Tool System | ✅ | ✅ (13 built-in tools) |
| Multi-Agent | ✅ | ✅ (6 specialized agents) |
| Permissions | ✅ | ✅ (Granular per-agent) |
| Task Tracking | ✅ | ✅ (TodoWrite/Read) |
| Web Access | ✅ | ✅ (WebFetch) |
| LSP Integration | ✅ | ✅ (Experimental) |
| MCP Servers | ✅ | ✅ (Configurable) |
| Local Models | ❌ | ✅ (Dual GPU Support) |

## Troubleshooting

### Model Not Responding
```bash
# Check if llama-cpp is running
make status

# Check logs
make logs-follow

# Restart services
make restart
```

### Permission Issues
Edit `opencode.json` permission settings:
- `"ask"` - Prompt for approval
- `"allow"` - Auto-approve
- `"deny"` - Block action

### Agent Not Available
Verify agent is defined in `opencode.json` under the `agent` section.

## Resources

- [OpenCode Documentation](https://opencode.ai/docs/)
- [Config Reference](https://opencode.ai/docs/config/)
- [Agents Guide](https://opencode.ai/docs/agents/)
- [Tools Reference](https://opencode.ai/docs/tools/)
- [Modes Documentation](https://opencode.ai/docs/modes/)

## Next Steps

1. **Test the Configuration**: Start OpenCode and verify all agents work
2. **Customize Agents**: Adjust temperatures and tools based on your workflow
3. **Add Instructions**: Create project-specific guidelines in `.opencode/instructions.md`
4. **Enable LSP**: For enhanced code intelligence
5. **Configure MCP**: Connect external tools and databases as needed

Your OpenCode setup is now optimized for advanced development workflows with Claude Code-like capabilities!
