import type { RequestHandler } from 'express';
import { resolveElderScope } from '../../common/access/elderScope';
import type { FamilyService } from '../family/family.service';
import type { AiService } from './ai.service';

const DEFAULT_LANGUAGE = 'en';

export class AiController {
  constructor(
    private readonly service: AiService,
    private readonly family: FamilyService,
  ) {}

  /** ELDER-only: the medicine assistant answers only for the asking elder's own data. */
  askMedicineQuestion: RequestHandler = async (req, res, next) => {
    try {
      const elderId = req.auth!.userId;
      const { query, language } = req.body as { query: string; language?: string };
      const answer = await this.service.askMedicineQuestion(elderId, query, language ?? DEFAULT_LANGUAGE);
      res.json({ success: true, ...answer });
    } catch (e) {
      next(e);
    }
  };

  /** Elder or a linked caregiver, same scoping as every other elder-data read. */
  getCaregiverInsight: RequestHandler = async (req, res, next) => {
    try {
      const elderId = await resolveElderScope(req.auth!, req.query.elderId as string | undefined, this.family);
      const language = (req.query.language as string | undefined) ?? DEFAULT_LANGUAGE;
      const answer = await this.service.getCaregiverInsight(elderId, language);
      res.json({ success: true, ...answer });
    } catch (e) {
      next(e);
    }
  };
}
