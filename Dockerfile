# Use Alpine Linux as the base image
FROM alpine:latest

# Install dependencies (git, bash, and curl)
RUN apk update && apk add --no-cache \
  git \
  bash \
  curl

# Set the working directory
WORKDIR /action

# Copy the entrypoint.sh script into the container
COPY entrypoint.sh /action/entrypoint.sh

# Make the entrypoint.sh script executable
RUN chmod +x /action/entrypoint.sh

# Set the entrypoint to use the script
ENTRYPOINT ["/action/entrypoint.sh"]
