# Member-Based CBHI Backend

Backend foundation for the Maya City member-based CBHI application.

## What this service is for

- Household and beneficiary registration
- National ID-based verification
- Coverage renewal and premium payment tracking
- Claims submission and approval workflows
- Health facility directory and service management
- Notifications, reporting, and audit-ready data storage

## Local setup

1. Copy `.env.example` to `.env`.
2. Set the PostgreSQL and integration values.
3. Run `npm install` if dependencies are not already installed.
4. Start the API with `npm run start:dev`.

## Scripts

- `npm run start` runs the API once
- `npm run start:dev` runs the API in watch mode
- `npm run build` compiles TypeScript to `dist`
- `npm run test` runs the unit tests

## Notes

- The backend assumes PostgreSQL.
- TypeORM synchronization is enabled by default outside production so the schema can evolve quickly during early development.
-  National ID, and notification integrations are scaffolded through environment variables and can be wired in next.

## Production deployment

- Use Supabase for PostgreSQL.
- Keep `DB_SSL=true` in production.
- Deploy the NestJS API to a Node runtime such as Render, Railway, Fly.io, or another container/VM host.
