import type { RequestHandler } from 'express';
import { resolveElderScope } from '../../common/access/elderScope';
import { daysAgoRange } from '../../common/utils/dateRange';
import type { FamilyService } from '../family/family.service';
import type { VoiceService } from './voice.service';

const DEFAULT_RANGE_DAYS = 30;

export class VoiceController {
  constructor(
    private readonly service: VoiceService,
    private readonly family: FamilyService,
  ) {}

  process: RequestHandler = async (req, res, next) => {
    try {
      const elderId = req.auth!.userId;
      const { transcript, language } = req.body as { transcript: string; language?: string };
      const result = await this.service.process(elderId, transcript, language);
      res.json({ success: true, ...result });
    } catch (e) {
      next(e);
    }
  };

  listInteractions: RequestHandler = async (req, res, next) => {
    try {
      const elderId = await resolveElderScope(req.auth!, req.query.elderId as string | undefined, this.family);
      const { from: defaultFrom, to: defaultTo } = daysAgoRange(DEFAULT_RANGE_DAYS);
      const from = req.query.from ? new Date(`${req.query.from as string}T00:00:00.000Z`) : defaultFrom;
      const to = req.query.to ? new Date(`${req.query.to as string}T23:59:59.999Z`) : defaultTo;
      const interactions = await this.service.listInteractions(elderId, from, to);
      res.json({ success: true, interactions });
    } catch (e) {
      next(e);
    }
  };
}
