# 파이프라인 노드(agent any)에서 aws CLI / jq / docker CLI를 쓰기 위한 커스텀 Jenkins 이미지
# - 2단계(Docker Build & Push): docker CLI + aws CLI 필요
# - 3단계(Deploy to ECS):        aws CLI + jq 필요
# 공식 jenkins/jenkins:lts는 Debian 기반이라 apt-get을 사용한다.
FROM jenkins/jenkins:lts

# 패키지 설치는 root 권한이 필요하므로 잠시 root로 전환
USER root

# docker CLI 저장소 등록에 필요한 기본 도구
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      ca-certificates curl gnupg unzip jq \
 && rm -rf /var/lib/apt/lists/*

# docker CLI 설치 (데몬이 아니라 CLI만. 실제 빌드는 마운트한 호스트 docker 소켓이 처리)
RUN install -m 0755 -d /etc/apt/keyrings \
 && curl -fsSL https://download.docker.com/linux/debian/gpg \
      | gpg --dearmor -o /etc/apt/keyrings/docker.gpg \
 && chmod a+r /etc/apt/keyrings/docker.gpg \
 && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian $(. /etc/os-release && echo $VERSION_CODENAME) stable" \
      > /etc/apt/sources.list.d/docker.list \
 && apt-get update \
 && apt-get install -y --no-install-recommends docker-ce-cli \
 && rm -rf /var/lib/apt/lists/*

# aws CLI v2 설치 (아키텍처에 맞는 번들 선택)
RUN set -eux; \
    arch="$(dpkg --print-architecture)"; \
    case "$arch" in \
      amd64) url="https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" ;; \
      arm64) url="https://awscli.amazonaws.com/awscli-exe-linux-aarch64.zip" ;; \
      *) echo "unsupported arch: $arch" >&2; exit 1 ;; \
    esac; \
    curl -fsSL "$url" -o /tmp/awscliv2.zip; \
    unzip -q /tmp/awscliv2.zip -d /tmp; \
    /tmp/aws/install; \
    rm -rf /tmp/awscliv2.zip /tmp/aws; \
    aws --version; jq --version

# 설치가 끝났으니 보안을 위해 기본 실행 사용자(jenkins)로 복귀
USER jenkins
