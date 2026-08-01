# Frontend

Next.js App Router UI for the ACI Capstone 1 license-verification backend. Under active development — the plan and its per-section progress markers live in [`../frontend_tutorial.md`](../frontend_tutorial.md); architecture and working conventions live in [`CLAUDE.md`](CLAUDE.md).

## Run it

```bash
bun install
bun dev          # http://localhost:3000
```

`bun run build` currently fails — `app/page.tsx` reads `sessionStorage` in a `useState` initializer, which also runs during static prerender (tutorial §6.6 item 1).

## Notes

- `next.config.ts` sets `output: "export"` (static HTML/JS to `./out`, no Node server) and `images.unoptimized`, so the built site can be served from S3/CloudFront. There is no Vercel deployment.
- Type: IBM Plex Sans/Mono via `next/font/google` (`app/fonts.ts`).
- Cognito is **not deployed yet**. `/login` uses a synthetic session flag in `sessionStorage`; the real Amplify `signIn`/`getCurrentUser` calls sit commented out beside it.
- The backend endpoints the app fetches (`/api/upload-url`, `/api/status/{uuid}`) are **not built yet** either — see `../frontend_tutorial.md` §2.2.