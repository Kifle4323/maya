import { ConsoleLogger, Injectable, LogLevel } from '@nestjs/common';

/**
 * Structured JSON logger for production.
 * In development: pretty-prints to console.
 * In production: outputs JSON for log aggregators (CloudWatch, Datadog, etc.)
 */
@Injectable()
export class CbhiLogger extends ConsoleLogger {
  private readonly isProduction = process.env.NODE_ENV === 'production';

  protected formatMessage(
    logLevel: LogLevel,
    message: unknown,
    pidMessage: string,
    formattedLogLevel: string,
    contextMessage: string,
    timestampDiff: string,
  ): string {
    if (!this.isProduction) {
      return super.formatMessage(
        logLevel,
        message,
        pidMessage,
        formattedLogLevel,
        contextMessage,
        timestampDiff,
      );
    }

    // JSON format for production
    const entry = {
      level: logLevel,
      timestamp: new Date().toISOString(),
      context: this.context ?? 'App',
      message: typeof message === 'string' ? message : JSON.stringify(message),
      pid: process.pid,
    };

    return JSON.stringify(entry) + '\n';
  }
}
