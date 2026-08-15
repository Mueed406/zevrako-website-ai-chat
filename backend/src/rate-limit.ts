import type { NextFunction, Request, Response } from 'express';
import { AppError } from './errors.js';

export function rateLimit(max: number, windowMs: number) {
  const buckets = new Map<string, { count: number; reset: number }>();
  return (req: Request, _res: Response, next: NextFunction) => {
    const key = `${req.ip}:${req.visitor?.visitorId ?? 'public'}`;
    const now = Date.now(); const bucket = buckets.get(key);
    if (!bucket || bucket.reset <= now) { buckets.set(key, { count: 1, reset: now + windowMs }); return next(); }
    if (bucket.count >= max) return next(new AppError('rate_limited', 'Too many requests. Please wait and try again.', 429, true));
    bucket.count += 1; next();
  };
}
