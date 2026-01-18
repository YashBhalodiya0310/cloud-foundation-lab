FROM alpine:3.20

RUN apk add --no-cache bash coreutils findutils dos2unix

WORKDIR /app

COPY scripts/scan_repo.sh /app/scan_repo.sh

RUN dos2unix /app/scan_repo.sh && chmod +x /app/scan_repo.sh

ENTRYPOINT ["bash", "/app/scan_repo.sh"]
