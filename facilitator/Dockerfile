FROM node:18-alpine

# Create app directory
WORKDIR /usr/src/app

# Install app dependencies and SSH client for connecting to jumphost
RUN apk add --no-cache openssh-client

# Install dependencies
# A wildcard is used to ensure both package.json AND package-lock.json are copied
COPY package*.json ./

# Install dependencies
# package-lock.json is not tracked in this repo, so `npm ci` cannot be used here
RUN npm install --omit=dev

# Bundle app source
COPY . .

# Windows worktrees may still contain CRLF despite Git's LF checkout rule.
# Normalize before packaging exam scripts or executing the entrypoint.
RUN find /usr/src/app -path /usr/src/app/node_modules -prune -o \
    -type f -name '*.sh' -exec sed -i 's/\r$//' {} \;

# Create logs directory
RUN mkdir -p logs

# Create a non-root user and switch to it
RUN addgroup -g 1001 -S nodejs && \
    adduser -S nodeuser -u 1001 -G nodejs

# Setup SSH for passwordless authentication
RUN mkdir -p /home/nodeuser/.ssh && \
    chmod 700 /home/nodeuser/.ssh && \
    echo "Host jumphost\n\tStrictHostKeyChecking no\n\tUserKnownHostsFile /dev/null" > /home/nodeuser/.ssh/config && \
    chmod 600 /home/nodeuser/.ssh/config && \
    chown -R nodeuser:nodejs /home/nodeuser/.ssh

# Change ownership of the app files to the non-root user
RUN chown -R nodeuser:nodejs /usr/src/app

# Expose the service port
EXPOSE 3000

# Use the normalized entrypoint rather than copying the Windows source again.
RUN cp /usr/src/app/entrypoint.sh /home/nodeuser/entrypoint.sh

# Make entrypoint.sh executable
RUN chmod a+rx /home/nodeuser/entrypoint.sh && \
    /bin/sh -n /home/nodeuser/entrypoint.sh

# Switch to non-root user
USER nodeuser

ENTRYPOINT ["/bin/sh", "/home/nodeuser/entrypoint.sh"]
