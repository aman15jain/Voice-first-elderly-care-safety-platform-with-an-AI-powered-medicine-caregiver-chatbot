-- CreateEnum
CREATE TYPE "DoseStatus" AS ENUM ('SCHEDULED', 'REMINDED', 'TAKEN', 'SKIPPED', 'MISSED');

-- CreateEnum
CREATE TYPE "NotificationType" AS ENUM ('MISSED_DOSE');

-- AlterEnum
-- This migration adds more than one value to an enum.
-- With PostgreSQL versions 11 and earlier, this is not possible
-- in a single migration. This can be worked around by creating
-- multiple migrations, each migration adding only one value to
-- the enum.


ALTER TYPE "AuditAction" ADD VALUE 'MEDICINE_CREATED';
ALTER TYPE "AuditAction" ADD VALUE 'MEDICINE_UPDATED';
ALTER TYPE "AuditAction" ADD VALUE 'MEDICINE_DELETED';
ALTER TYPE "AuditAction" ADD VALUE 'DOSE_TAKEN';
ALTER TYPE "AuditAction" ADD VALUE 'DOSE_SKIPPED';
ALTER TYPE "AuditAction" ADD VALUE 'DOSE_MISSED';

-- CreateTable
CREATE TABLE "medicines" (
    "id" UUID NOT NULL,
    "elder_id" UUID NOT NULL,
    "name" TEXT NOT NULL,
    "dosage" TEXT NOT NULL,
    "instructions" TEXT,
    "is_active" BOOLEAN NOT NULL DEFAULT true,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "medicines_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "medicine_schedules" (
    "id" UUID NOT NULL,
    "medicine_id" UUID NOT NULL,
    "elder_id" UUID NOT NULL,
    "times_of_day" TEXT[],
    "days_of_week" INTEGER[],
    "start_date" DATE NOT NULL,
    "end_date" DATE,
    "is_active" BOOLEAN NOT NULL DEFAULT true,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "medicine_schedules_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "medicine_doses" (
    "id" UUID NOT NULL,
    "schedule_id" UUID NOT NULL,
    "medicine_id" UUID NOT NULL,
    "elder_id" UUID NOT NULL,
    "scheduled_for" TIMESTAMP(3) NOT NULL,
    "status" "DoseStatus" NOT NULL DEFAULT 'SCHEDULED',
    "reminded_at" TIMESTAMP(3),
    "responded_at" TIMESTAMP(3),
    "missed_at" TIMESTAMP(3),
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "medicine_doses_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "notifications" (
    "id" UUID NOT NULL,
    "recipient_id" UUID NOT NULL,
    "type" "NotificationType" NOT NULL,
    "title" TEXT NOT NULL,
    "body" TEXT NOT NULL,
    "data" JSONB,
    "read_at" TIMESTAMP(3),
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "notifications_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "medicines_elder_id_idx" ON "medicines"("elder_id");

-- CreateIndex
CREATE INDEX "medicine_schedules_elder_id_idx" ON "medicine_schedules"("elder_id");

-- CreateIndex
CREATE INDEX "medicine_doses_elder_id_scheduled_for_idx" ON "medicine_doses"("elder_id", "scheduled_for");

-- CreateIndex
CREATE UNIQUE INDEX "medicine_doses_schedule_id_scheduled_for_key" ON "medicine_doses"("schedule_id", "scheduled_for");

-- CreateIndex
CREATE INDEX "notifications_recipient_id_created_at_idx" ON "notifications"("recipient_id", "created_at");

-- AddForeignKey
ALTER TABLE "medicines" ADD CONSTRAINT "medicines_elder_id_fkey" FOREIGN KEY ("elder_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "medicine_schedules" ADD CONSTRAINT "medicine_schedules_medicine_id_fkey" FOREIGN KEY ("medicine_id") REFERENCES "medicines"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "medicine_schedules" ADD CONSTRAINT "medicine_schedules_elder_id_fkey" FOREIGN KEY ("elder_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "medicine_doses" ADD CONSTRAINT "medicine_doses_schedule_id_fkey" FOREIGN KEY ("schedule_id") REFERENCES "medicine_schedules"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "medicine_doses" ADD CONSTRAINT "medicine_doses_elder_id_fkey" FOREIGN KEY ("elder_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "notifications" ADD CONSTRAINT "notifications_recipient_id_fkey" FOREIGN KEY ("recipient_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;
