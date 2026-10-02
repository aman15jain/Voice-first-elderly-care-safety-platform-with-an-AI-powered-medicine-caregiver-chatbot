import type { RequestHandler } from 'express';
import type { AuthService } from './auth.service';

export class AuthController {
  constructor(private readonly service: AuthService) {}

  register: RequestHandler = async (req, res, next) => {
    try {
      const session = await this.service.register(req.body);
      res.status(201).json({ success: true, ...session });
    } catch (e) {
      next(e);
    }
  };

  login: RequestHandler = async (req, res, next) => {
    try {
      const session = await this.service.login(req.body.email, req.body.password);
      res.json({ success: true, ...session });
    } catch (e) {
      next(e);
    }
  };

  refresh: RequestHandler = async (req, res, next) => {
    try {
      const session = await this.service.refresh(req.body.refreshToken);
      res.json({ success: true, ...session });
    } catch (e) {
      next(e);
    }
  };

  logout: RequestHandler = async (req, res, next) => {
    try {
      await this.service.logout(req.body.refreshToken);
      res.status(204).send();
    } catch (e) {
      next(e);
    }
  };
}
