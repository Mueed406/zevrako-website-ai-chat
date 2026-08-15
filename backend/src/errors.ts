export class AppError extends Error {
  constructor(
    readonly code: string,
    message: string,
    readonly status: number,
    readonly retryable = false,
  ) { super(message); }
}

export function safeError(error: unknown): AppError {
  if (error instanceof AppError) return error;
  return new AppError('internal_error', 'The request could not be completed.', 500, true);
}
