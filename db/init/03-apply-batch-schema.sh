#!/bin/bash
set -e

# ✅ closet-batch DB에 배치 schema.sql을 적용
psql -v ON_ERROR_STOP=1 -U "closet-user" -d "closet-batch" -f /docker-entrypoint-initdb.d/batch/schema.sql