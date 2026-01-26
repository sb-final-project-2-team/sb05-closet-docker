-- ===========================
-- DROP TABLES (Dependencies 고려)
-- ===========================

DROP TABLE IF EXISTS notifications CASCADE;
DROP TABLE IF EXISTS direct_messages CASCADE;
DROP TABLE IF EXISTS follows CASCADE;
DROP TABLE IF EXISTS recommendations CASCADE;
DROP TABLE IF EXISTS weather_regions CASCADE;
DROP TABLE IF EXISTS weather_data CASCADE;
DROP TABLE IF EXISTS likes CASCADE;
DROP TABLE IF EXISTS comments CASCADE;
DROP TABLE IF EXISTS feeds CASCADE;
DROP TABLE IF EXISTS clothes_attributes_values CASCADE;
DROP TABLE IF EXISTS clothes CASCADE;
DROP TABLE IF EXISTS clothes_attributes CASCADE;
DROP TABLE IF EXISTS users CASCADE;
DROP TABLE IF EXISTS binary_contents CASCADE;
DROP TABLE IF EXISTS ootds CASCADE;

-- ===========================
-- DROP ENUM TYPES
-- ===========================

DROP TYPE IF EXISTS forecast_kind_enum;
DROP TYPE IF EXISTS sky_status_enum;
DROP TYPE IF EXISTS precipitation_type_enum;
DROP TYPE IF EXISTS wind_as_word_enum;

-- ===========================
-- PostgreSQL DDL
-- ===========================

-- 1. Binary Contents
CREATE TABLE binary_contents
(
    id           UUID PRIMARY KEY,
    file_name    VARCHAR(255) NOT NULL,
    file_url     VARCHAR(500) NOT NULL,
    size         BIGINT       NOT NULL,
    content_type VARCHAR(50)  NOT NULL,
    created_at   TIMESTAMPTZ DEFAULT NOW(),
    updated_at   TIMESTAMPTZ
);

-- 2. Users
CREATE TABLE users
(
    id                       UUID PRIMARY KEY,
    binary_content_id        UUID,
    weather_id               UUID,
    name                     VARCHAR(50)  NOT NULL,
    email                    VARCHAR(120) NOT NULL UNIQUE,
    password                 VARCHAR(255) NOT NULL,
    provider                 VARCHAR(20)  NOT NULL DEFAULT 'LOCAL' CHECK (provider IN ('LOCAL', 'GOOGLE', 'KAKAO')),
    provider_id              VARCHAR(255) NOT NULL,
    gender                   VARCHAR(10) CHECK (gender IN ('MALE', 'FEMALE', 'OTHER')),
    role                     VARCHAR(10)  NOT NULL DEFAULT 'USER' CHECK (role IN ('ADMIN', 'USER')),
    birth                    TIMESTAMPTZ,
    temperature_sensitivity  INTEGER      NOT NULL DEFAULT 3,
    temp_password            VARCHAR(255),
    temp_password_expired_at TIMESTAMPTZ,
    locked                   BOOLEAN,
    created_at               TIMESTAMPTZ           DEFAULT NOW(),
    updated_at               TIMESTAMPTZ,
    FOREIGN KEY (binary_content_id) REFERENCES binary_contents (id)
);


-- 3. Clothes Attribute Definitions
CREATE TABLE clothes_attributes
(
    id                UUID PRIMARY KEY,
    name              VARCHAR(100) NOT NULL UNIQUE,
    attributes_values JSONB        NOT NULL,
    created_at        TIMESTAMPTZ DEFAULT NOW()
);

-- 4. Clothes
CREATE TABLE clothes
(
    id                    UUID PRIMARY KEY,
    owner_id              UUID         NOT NULL,
    name                  VARCHAR(255) NOT NULL,
    binary_content_id     UUID,
    type                  VARCHAR(10)
        CHECK (type IN
               ('TOP', 'BOTTOM', 'DRESS', 'OUTER', 'UNDERWEAR', 'ACCESSORY', 'SHOES', 'SOCKS',
                'HAT', 'BAG', 'SCARF',
                'ETC')),
    created_at            TIMESTAMPTZ DEFAULT NOW(),
    updated_at            TIMESTAMPTZ,
    FOREIGN KEY (owner_id) REFERENCES users (id),
    FOREIGN KEY (binary_content_id) REFERENCES binary_contents (id)
);

-- 5. 속성 값
CREATE TABLE clothes_attributes_values
(
    id                    UUID PRIMARY KEY,
    clothes_id            UUID        NOT NULL,
    clothes_attributes_id UUID        NOT NULL,
    value                 VARCHAR(20) NOT NULL,
    FOREIGN KEY (clothes_id) REFERENCES clothes (id),
    FOREIGN KEY (clothes_attributes_id) REFERENCES clothes_attributes (id),
    UNIQUE (clothes_id, clothes_attributes_id) -- 하나의 옷에 속성 1개만 적용되도록
);

-- 예보 종류
CREATE TYPE forecast_kind_enum AS ENUM ('ULTRA_NOW', 'ULTRA_FCST', 'SHORT_FCST');

-- 하늘 상태 (기상청 SKY 코드 매핑, 강수는 precipitation_type으로 분리)
CREATE TYPE sky_status_enum AS ENUM ('CLEAR', 'MOSTLY_CLOUDY', 'CLOUDY');

-- 강수 상태
CREATE TYPE precipitation_type_enum AS ENUM ('NONE', 'RAIN', 'RAIN_SNOW', 'SNOW', 'SHOWER');

-- 바람 세기
CREATE TYPE wind_as_word_enum AS ENUM ('WEAK','MODERATE','STRONG');

-- 5. Weather Data
CREATE TABLE weather_data
(
    id                          UUID PRIMARY KEY,
    weather_region_id           UUID                    NOT NULL,

    forecast_kind               forecast_kind_enum      NOT NULL,
    forecast_at                 TIMESTAMPTZ             NOT NULL,
    forecasted_at               TIMESTAMPTZ             NOT NULL,

    sky_status                  sky_status_enum         NOT NULL,

    temperature_current         DOUBLE PRECISION        NOT NULL,
    temperature_comp_prev_day   DOUBLE PRECISION,
    temperature_min             DOUBLE PRECISION        NOT NULL,
    temperature_max             DOUBLE PRECISION        NOT NULL,

    precipitation_type          precipitation_type_enum NOT NULL,
    precipitation_amount        DOUBLE PRECISION        NOT NULL,
    precipitation_prob          DOUBLE PRECISION        NOT NULL,

    humidity_current            DOUBLE PRECISION        NOT NULL,
    humidity_comp_to_day_before DOUBLE PRECISION,

    wind_speed                  DOUBLE PRECISION        NOT NULL,
    wind_as_word                wind_as_word_enum       NOT NULL,

    updated_at                  TIMESTAMPTZ             NOT NULL DEFAULT NOW(),
    created_at                  TIMESTAMPTZ             NOT NULL DEFAULT NOW()
);


-- 6. Weather Region Targets
CREATE TABLE weather_regions
(
    id                UUID PRIMARY KEY,
    weather_data_id   UUID,
    x                 INT         NOT NULL,
    y                 INT         NOT NULL,
    latitude          DOUBLE PRECISION,
    longitude         DOUBLE PRECISION,
    location_names    VARCHAR(255),
    last_collected_at TIMESTAMPTZ,
    updated_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (x, y)
);

-- 7. Feeds (OOTD)
CREATE TABLE feeds
(
    id            UUID PRIMARY KEY,
    user_id       UUID NOT NULL,
    weather_id    UUID NOT NULL,
    content       VARCHAR(2000),
    comment_count INTEGER     DEFAULT 0,
    like_count    INTEGER     DEFAULT 0,
    created_at    TIMESTAMPTZ DEFAULT NOW(),
    updated_at    TIMESTAMPTZ,
    FOREIGN KEY (user_id) REFERENCES users (id),
    FOREIGN KEY (weather_id) REFERENCES weather_data (id)
);

CREATE TABLE ootds
(
    id         UUID PRIMARY KEY,
    feed_id    UUID NOT NULL,
    clothes_id UUID NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),

    CONSTRAINT fk_ootds_feed
        FOREIGN KEY (feed_id) REFERENCES feeds (id)
            ON DELETE CASCADE,

    CONSTRAINT fk_ootds_clothes
        FOREIGN KEY (clothes_id) REFERENCES clothes (id)
);

-- 8. Comments
CREATE TABLE comments
(
    id         UUID PRIMARY KEY,
    feed_id    UUID NOT NULL,
    user_id    UUID NOT NULL,
    content    TEXT NOT NULL CHECK (char_length(content) <= 500),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    FOREIGN KEY (feed_id) REFERENCES feeds (id),
    FOREIGN KEY (user_id) REFERENCES users (id)
);

-- 9. Feed Likes
CREATE TABLE likes
(
    id         UUID PRIMARY KEY,
    user_id    UUID NOT NULL,
    feed_id    UUID NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE (user_id, feed_id),
    FOREIGN KEY (user_id) REFERENCES users (id),
    FOREIGN KEY (feed_id) REFERENCES feeds (id)
);

-- 10. Recommendations
CREATE TABLE recommendations
(
    id         UUID PRIMARY KEY,
    user_id    UUID NOT NULL,
    weather_id UUID NOT NULL,
    clothes_id UUID NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    FOREIGN KEY (user_id) REFERENCES users (id),
    FOREIGN KEY (weather_id) REFERENCES weather_data (id),
    FOREIGN KEY (clothes_id) REFERENCES clothes (id)
);

-- 차후 FK 설정 user, weather만
ALTER TABLE weather_regions
    ADD CONSTRAINT fk_weather_regions_weather_data
        FOREIGN KEY (weather_data_id) REFERENCES weather_data (id)
            DEFERRABLE INITIALLY DEFERRED;

ALTER TABLE weather_data
    ADD CONSTRAINT fk_weather_data_regions
        FOREIGN KEY (weather_region_id) REFERENCES weather_regions (id)
            DEFERRABLE INITIALLY DEFERRED;

ALTER TABLE users
    ADD CONSTRAINT fk_users_weather_region
        FOREIGN KEY (weather_id) REFERENCES weather_regions (id);

-- 11. Follows
CREATE TABLE follows
(
    id          UUID PRIMARY KEY,
    follower_id UUID NOT NULL,
    followee_id UUID NOT NULL,
    created_at  TIMESTAMPTZ DEFAULT NOW(),
    FOREIGN KEY (follower_id) REFERENCES users (id),
    FOREIGN KEY (followee_id) REFERENCES users (id),
    UNIQUE (follower_id, followee_id)
);

-- 12. DM
CREATE TABLE direct_messages
(
    id          UUID PRIMARY KEY,
    dm_key      VARCHAR(255) NOT NULL,
    sender_id   UUID         NOT NULL,
    receiver_id UUID         NOT NULL,
    content     TEXT         NOT NULL,
    created_at  TIMESTAMPTZ DEFAULT NOW()
);
-- 13. Notification
CREATE TABLE notifications
(
    id          UUID PRIMARY KEY,
    receiver_id UUID         NOT NULL,
    title       VARCHAR(200) NOT NULL,
    content     TEXT         NOT NULL,
    level       VARCHAR(10)  NOT NULL CHECK (level IN ('INFO', 'WARNING', 'ERROR')),
    created_at  TIMESTAMPTZ DEFAULT NOW(),
    FOREIGN KEY (receiver_id) REFERENCES users (id)
);

-- #################################
-- ########## Index 추가 ############
-- #################################
CREATE INDEX idx_users_created_at_id ON users (created_at DESC, id DESC);
CREATE INDEX idx_users_email_id ON users (email ASC, id ASC);
CREATE INDEX idx_users_created_at_id_role_locked ON users (created_at DESC, id DESC, role, locked);

CREATE INDEX idx_feed_created_at_id_desc ON feeds (created_at DESC, id DESC);
CREATE INDEX idx_feed_like_Count_created_at_id_desc ON feeds (like_count DESC, created_at DESC, id DESC);

CREATE UNIQUE INDEX uk_weather_data
    ON weather_data (weather_region_id, forecast_at, forecast_kind);