-- CreateEnum
CREATE TYPE "VoiceIntentType" AS ENUM ('MEDICINE_STATUS', 'MEDICINE_INFO', 'ACTIVITY_STATUS', 'CALL_CONTACT', 'EMERGENCY_SOS', 'UNKNOWN');

-- CreateTable
CREATE TABLE "voice_interactions" (
    "id" UUID NOT NULL,
    "elder_id" UUID NOT NULL,
    "transcript" TEXT NOT NULL,
    "language" TEXT NOT NULL DEFAULT 'en',
    "intent_type" "VoiceIntentType" NOT NULL,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "voice_interactions_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "voice_interactions_elder_id_created_at_idx" ON "voice_interactions"("elder_id", "created_at");

-- AddForeignKey
ALTER TABLE "voice_interactions" ADD CONSTRAINT "voice_interactions_elder_id_fkey" FOREIGN KEY ("elder_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;
