# member-based-CBHI-

This repository contains three Flutter apps deployed as separate Vercel projects from the same GitHub monorepo:

- `member_based_cbhi`
- `cbhi_admin_desktop`
- `cbhi_facility_desktop`

## Vercel setup

Create three Vercel projects from the same GitHub repository and set each project's Root Directory to one of:

- `member_based_cbhi`
- `cbhi_admin_desktop`
- `cbhi_facility_desktop`

Each app already includes:

- `vercel.json` with the correct `buildCommand` and `outputDirectory`
- `vercel-build.sh` to install Flutter on Vercel and run `flutter build web --release`

## Notes

- If Vercel asks for a framework preset, choose `Other`.
- The build output directory is `build/web`.
- Add environment variables separately in each Vercel project if needed.

## Backend

The `backend` service is a NestJS API. Use Supabase for PostgreSQL, then deploy the API itself to a Node-friendly host.
