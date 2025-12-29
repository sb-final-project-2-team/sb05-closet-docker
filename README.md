## docker compose 사용법

실제 개발할땐 docker-compose-dev를 올려서 사용 (Postgres, Redis, zookeeper, Kafka만 넣음.)
docker compose -f docker-compose-dev.yml up -d

**service**에는 batch, api, nginx, sse-ws 올려놓고 작업하면 됩니다.