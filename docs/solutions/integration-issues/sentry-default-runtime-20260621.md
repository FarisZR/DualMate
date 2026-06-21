# Sentry default runtime configuration

DualMate now contains its runtime Sentry client configuration in `lib/common/logging/sentry_configuration.dart`.

Normal app builds no longer need a `SENTRY_DSN` Dart define to initialize Sentry. Release and environment metadata may still be provided with `SENTRY_RELEASE` and `SENTRY_ENVIRONMENT`.
