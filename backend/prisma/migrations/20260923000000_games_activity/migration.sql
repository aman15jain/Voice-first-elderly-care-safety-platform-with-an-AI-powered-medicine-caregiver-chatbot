-- CreateEnum
CREATE TYPE "GameType" AS ENUM ('MEMORY_MATCH', 'PATTERN_RECOGNITION', 'ATTENTION_EXERCISE', 'SEQUENCE_RECALL');

-- CreateEnum
CREATE TYPE "ActivityEventType" AS ENUM ('APP_OPENED');

-- CreateTable
CREATE TABLE "cognitive_games" (
    "id" UUID NOT NULL,
    "type" "GameType" NOT NULL,
    "name" TEXT NOT NULL,
    "description" TEXT NOT NULL,
    "is_active" BOOLEAN NOT NULL DEFAULT true,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "cognitive_games_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "game_sessions" (
    "id" UUID NOT NULL,
    "elder_id" UUID NOT NULL,
    "game_id" UUID NOT NULL,
    "difficulty" INTEGER NOT NULL,
    "score" INTEGER NOT NULL,
    "mistakes" INTEGER NOT NULL,
    "duration_seconds" INTEGER NOT NULL,
    "completed" BOOLEAN NOT NULL,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "game_sessions_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "activity_events" (
    "id" UUID NOT NULL,
    "elder_id" UUID NOT NULL,
    "type" "ActivityEventType" NOT NULL,
    "occurred_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "activity_events_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "cognitive_games_type_key" ON "cognitive_games"("type");

-- CreateIndex
CREATE INDEX "game_sessions_elder_id_created_at_idx" ON "game_sessions"("elder_id", "created_at");

-- CreateIndex
CREATE INDEX "game_sessions_elder_id_game_id_created_at_idx" ON "game_sessions"("elder_id", "game_id", "created_at");

-- CreateIndex
CREATE INDEX "activity_events_elder_id_occurred_at_idx" ON "activity_events"("elder_id", "occurred_at");

-- AddForeignKey
ALTER TABLE "game_sessions" ADD CONSTRAINT "game_sessions_elder_id_fkey" FOREIGN KEY ("elder_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "game_sessions" ADD CONSTRAINT "game_sessions_game_id_fkey" FOREIGN KEY ("game_id") REFERENCES "cognitive_games"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "activity_events" ADD CONSTRAINT "activity_events_elder_id_fkey" FOREIGN KEY ("elder_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- Seed the fixed catalog of built-in games (spec section 17). Stable ids so they never
-- need to be looked up by name; `updated_at` is set explicitly since it has no DB default.
INSERT INTO "cognitive_games" ("id", "type", "name", "description", "is_active", "updated_at") VALUES
    ('00000000-0000-0000-0000-000000000001', 'MEMORY_MATCH', 'Memory Match', 'Flip the cards and find the matching pairs.', true, CURRENT_TIMESTAMP),
    ('00000000-0000-0000-0000-000000000002', 'PATTERN_RECOGNITION', 'Pattern Recognition', 'Figure out what comes next in the pattern.', true, CURRENT_TIMESTAMP),
    ('00000000-0000-0000-0000-000000000003', 'ATTENTION_EXERCISE', 'Attention Exercise', 'Find the one symbol that is different from the rest.', true, CURRENT_TIMESTAMP),
    ('00000000-0000-0000-0000-000000000004', 'SEQUENCE_RECALL', 'Sequence Recall', 'Watch the sequence, then repeat it back in order.', true, CURRENT_TIMESTAMP);
