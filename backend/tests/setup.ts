process.env.NODE_ENV = 'test';
process.env.LOG_LEVEL = 'silent';
process.env.DATABASE_URL ??= 'postgresql://test:test@localhost:5432/test';
process.env.JWT_SECRET ??= 'test-access-secret-please-ignore';
process.env.JWT_REFRESH_SECRET ??= 'test-refresh-pepper-please-ignore';
