FROM debian:bookworm-slim

RUN apt-get update \
&& apt-get install -y --no-install-recommends \
ssh sshpass

WORKDIR /app

COPY . /app

# RUN chmod +x /app/entrypoint.sh

# START TEMPORARY COMMAND
RUN mkdir -p /root/.ssh \
&& chmod 700 /root/.ssh \
&& mv /app/ssh/config /root/.ssh/config \
&& rmdir /app/ssh \
&& chmod 600 /root/.ssh/config \
&& find /app -type f -name "*.sh" -exec chmod +x {} +
# END TEMPORARY COMMAND

ENTRYPOINT ["/app/entrypoint.sh"]
