####################################################################################################
## Builder
####################################################################################################
FROM rust:latest AS builder

RUN apt update && apt install -y musl-tools musl-dev pkg-config libssl-dev binutils upx-ucl
# We're targeting alpine, which is using musl instead of the glibc
# So we have to cross-compile for it
RUN rustup target add x86_64-unknown-linux-musl
# Depending on the app dependencies, some ca may break, so better safe than sorry
RUN update-ca-certificates
WORKDIR /app
COPY ./ .
# Build the app
RUN cargo build --target x86_64-unknown-linux-musl --release
# Optimize the app size aggresively by removing symbols (strip) and compressing it (upx)
RUN strip /app/target/x86_64-unknown-linux-musl/release/cat-server && \
    upx --best --lzma /app/target/x86_64-unknown-linux-musl/release/cat-server

####################################################################################################
## Final image
####################################################################################################
FROM alpine as release
# Copy the config files. Chmod are required is these can be copied from Windows
# which has no ACL
COPY --chmod=500 --chown=root:root init_container.sh /bin/
COPY --chmod=600 --chown=sshd:sshd sshd_config /etc/ssh/
COPY nginx.conf /etc/nginx/nginx.conf
# Add Runtime deps. Openrc/openssh for sshd, nginx as a reverse-proxy
# and su-exec to step down from root at runtime
ENV sysdirs="/bin   /etc    /lib    /sbin"
RUN apk add --no-cache openrc openssh nginx su-exec &&\
    # As weird at it seems, the root password MUST be "Docker!" to allow \
    # for SSH connections from the Azure portal
    echo "root:Docker!" | chpasswd &&\
    # The runtime user, having no home dir nor password
    adduser -HD -s /bin/ash appuser &&\
    # Generate SSH keys pairs. On Windows, the authorized cyphers may not work
    cd /etc/ssh && \
    ssh-keygen -A &&\
    cd - && \
    # Hardening part. As the root password is predefined, let's prevent the user
    # from root access some other ways \
    # First, remove all packages confs
    find $sysdirs -xdev -regex '.*apk.*' -exec rm -fr {} + && \
    # Next, ensure all system directories are owned by root and root only
    find $sysdirs -xdev -type d \
      -exec chown root:root {} \; \
      -exec chmod 0755 {} \; && \
    # Remove all SUID (files that can be exec with the ACL of another user)
    find $sysdirs -xdev -type f -a -perm +4000 -delete && \
    # Finally, remove all ACL-related programs
    find $sysdirs -xdev \( \
      -name hexdump -o \
      -name chgrp -o \
      -name chmod -o \
      -name chown -o \
      -name ln -o \
      -name od -o \
      -name strings -o \
      -name su \
      \) -delete

WORKDIR /app
# Copy the built app, only allowing our app user to execute it
COPY --from=builder --chmod=0500 --chown=appuser:appuser  /app/target/x86_64-unknown-linux-musl/release/cat-server ./

WORKDIR /home/site/wwwroot
EXPOSE 80 2222
ENTRYPOINT [ "/bin/init_container.sh" ]