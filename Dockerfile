# Use lightweight Node.js image
FROM node:20-alpine

# Install the router globally
RUN npm install -g @musistudio/claude-code-router

# Create the config directory
RUN mkdir -p /root/.claude-code-router

# Environment variables to force non-interactive mode (crucial for Docker)
ENV NON_INTERACTIVE_MODE=true
ENV HOST=0.0.0.0

# Expose the default port
EXPOSE 3456

# Start command
CMD ["ccr", "start"]
