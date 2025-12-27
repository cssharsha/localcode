# Project-Specific Instructions for OpenCode AI Agents

## Project Context

This is a local OpenCode setup with dual GPU support (Nvidia RTX 4070 + Intel Arc A770) running state-of-the-art coding models via llama.cpp.

## Development Guidelines

### Code Quality Standards

- Write clean, maintainable, and well-documented code
- Follow existing patterns and conventions in the codebase
- Prioritize readability over clever optimizations
- Add comments for complex logic, but let code be self-documenting when possible

### Git Workflow

- Write clear, descriptive commit messages
- Keep commits atomic and focused on single changes
- Reference issue numbers when applicable

### Docker and Infrastructure

- All services run via Docker Compose
- Use Makefile targets for common operations
- Models are cached in `/data/llama-models/`
- Configuration changes require service restart

### Model Management

- Single GPU models use CUDA backend (Nemotron, Qwen 7B, Nemotron Nano)
- Dual GPU models use Vulkan backend (Qwen 32B, DeepSeek V2 Lite)
- Switch models using `make use-<model>` targets
- Always verify model is running with `make current-model`

### Performance Considerations

- Larger models (32B, 16B) require both GPUs via Vulkan
- Smaller models (4B, 7B) run on single GPU via CUDA
- Context windows vary by model (4K to 163K tokens)
- Use appropriate model for the task complexity

## Agent-Specific Guidelines

### When Using Plan Agent

- Focus on architecture and design decisions
- Provide detailed analysis without implementing
- Consider scalability, maintainability, and performance
- Document trade-offs and alternatives

### When Using Build Agent

- Implement with production-quality code
- Test thoroughly before marking complete
- Follow established patterns
- Update documentation as needed

### When Using Review Agent

- Focus on code quality, security, and best practices
- Suggest improvements constructively
- Check for common vulnerabilities (SQL injection, XSS, etc.)
- Verify error handling and edge cases

### When Using Debug Agent

- Systematically investigate issues
- Check logs, configurations, and dependencies
- Verify assumptions with tests
- Document findings and solutions

### When Using Explore Agent

- Provide quick, focused searches
- Return relevant file paths and code snippets
- Help navigate large codebases efficiently
- Use glob patterns and grep effectively

## Technology Stack

- **Container Runtime**: Docker with Docker Compose
- **Model Runtime**: llama.cpp (CUDA and Vulkan backends)
- **Router**: claude-code-router for API compatibility
- **GPUs**: Nvidia RTX 4070 (primary) + Intel Arc A770 (secondary)
- **Models**: Qwen2.5-Coder, DeepSeek-Coder-V2, Nemotron family

## Common Patterns

### Switching Models

```bash
# Stop current model
make stop

# Switch to desired model
make use-qwen32b-dualgpu

# Verify it's running
make current-model
make logs-follow
```

### Debugging Services

```bash
# Check service status
make status

# View logs
make logs-llama
make logs-router

# Restart if needed
make restart
```

### Configuration Updates

1. Edit configuration files (opencode.json, docker-compose.yml, etc.)
2. Restart affected services
3. Verify changes took effect
4. Test functionality

## Best Practices

- **Always verify before modifying**: Read files and understand context
- **Test incrementally**: Make small changes and verify
- **Document decisions**: Explain "why" not just "what"
- **Consider resources**: Balance model size with available VRAM
- **Monitor performance**: Use `make gpu-check` to verify GPU utilization
- **Keep backups**: Use `make backup` before major configuration changes

## Error Handling

- Check logs first: `make logs-follow`
- Verify services are running: `make status`
- Confirm GPU access: `make gpu-check`
- Check model availability: `make model-info`
- Restore from backup if needed: `make restore`

## Resources

- Makefile contains all available commands: `make help`
- OpenCode documentation: https://opencode.ai/docs/
- Configuration reference: See OPENCODE_SETUP.md
- Model information in docker-compose files
