@AGENTS.md

# CLAUDE.md — BengkelIn Admin (Next.js Web)

This file guides Claude Code when working inside the `admin/` directory. These rules are **mandatory** and override default behavior.

## Project

**BengkelIn Admin** is the web admin dashboard for the BengkelIn platform. It manages the same data as the SwiftUI iOS app (see the repo-root [`../CLAUDE.md`](../CLAUDE.md) for the iOS app and the full Supabase schema). It talks to the **same Supabase project** the iOS app uses:

```
Supabase URL: https://ipxwpxozreksmuiztwcy.supabase.co
```

### Stack

| Concern | Choice |
|---------|--------|
| Framework | Next.js 16 (App Router, RSC) — `next@16.2.7` |
| React | 19 |
| Language | TypeScript (`strict: true`) |
| UI | **shadcn/ui** (`base-nova` style, base color `neutral`, CSS variables) — already installed under `src/components/ui/` |
| Styling | Tailwind CSS v4 |
| Icons | `lucide-react` |
| Toasts | `sonner` |
| Data | Supabase (`@supabase/supabase-js` + `@supabase/ssr`) |
| Package manager | **pnpm** |

> ⚠️ This is **not** the Next.js in your training data (see `AGENTS.md`). Before using a Next.js API, read the matching guide in `node_modules/next/dist/docs/` and heed deprecation notices.

## Commands

```sh
pnpm dev      # start dev server
pnpm build    # production build
pnpm start    # serve production build
pnpm lint     # eslint
```

Always run `pnpm lint` and `pnpm build` before declaring work done — `build` is the real type check (`tsc` runs as part of it).

---

## Non-Negotiable Conventions

These are the rules the rest of this document exists to enforce. Violating any of them is a bug.

1. **No `any`.** The `any` type is banned everywhere — props, state, API responses, callbacks, generics. If a type is genuinely unknown, use `unknown` and narrow it. Reach for generics, union types, or `zod`-inferred types instead. Prefer `interface` for object shapes; `type` for unions/aliases.
2. **Every interface lives in a `types/` folder.** Never declare an `interface` (or exported `type` alias for a data shape) inline in a component, hook, or service file. Component prop interfaces, DB row shapes, DTOs, and API payloads all go in a `types/` file and are imported.
3. **Feature-based structure.** Code is grouped by feature, not by technical layer (see below). Shared/global code lives in the top-level `src/` folders; feature code lives under `src/features/<feature>/`.
4. **Every React hook lives in a `hooks/` folder.** Custom hooks (anything starting with `use`) are never defined inline in a component. Global hooks go in `src/hooks/`; feature hooks go in `src/features/<feature>/hooks/`. One hook per file.
5. **Use shadcn/ui.** Build UI from the primitives in `src/components/ui/`. Do not hand-roll buttons, inputs, dialogs, tables, etc. Add missing primitives with `pnpm dlx shadcn@latest add <component>` — never copy them in by hand.
6. **Clean code.** Small, single-responsibility functions and components. Descriptive names. No dead code, no commented-out blocks, no `console.log` left behind. Server Components by default; add `"use client"` only when a component needs interactivity, state, or browser APIs.

---

## Directory Structure (Feature-Based)

```
admin/src/
├── app/                          # Next.js App Router — routing only (thin)
│   ├── layout.tsx                # Root layout (providers live here)
│   ├── page.tsx
│   └── <route>/
│       └── page.tsx              # Page = compose feature components; minimal logic
│
├── components/                   # GLOBAL shared components (used across features)
│   ├── ui/                       # shadcn/ui primitives — DO NOT edit by hand
│   └── ...                       # app-wide composites (e.g. AppSidebar, PageHeader)
│
├── hooks/                        # GLOBAL shared hooks (e.g. use-mobile.ts)
│
├── types/                        # GLOBAL shared types/interfaces
│   ├── database.ts               # Supabase row types (mirror the DB schema)
│   └── ...
│
├── lib/                          # GLOBAL utilities + client setup
│   ├── utils.ts                  # cn() etc.
│   └── supabase/                 # Supabase client factories (see below)
│       ├── client.ts             # browser client
│       └── server.ts             # server client (RSC / route handlers)
│
└── features/                     # FEATURE MODULES
    └── <feature>/                # e.g. bengkels, users, service-requests, vouchers
        ├── components/           # feature-specific components
        ├── hooks/                # feature-specific hooks (one per file)
        ├── services/             # Supabase data access for this feature
        └── types/                # interfaces for this feature (props, rows, DTOs)
```

### Where does a file go?

| You're adding... | Put it in... |
|------------------|--------------|
| A route/page | `src/app/<route>/page.tsx` (compose feature components, keep thin) |
| A component used by one feature | `src/features/<feature>/components/` |
| A component used by 2+ features | `src/components/` |
| A shadcn primitive | `src/components/ui/` (via the shadcn CLI) |
| A hook used by one feature | `src/features/<feature>/hooks/` |
| A hook used by 2+ features | `src/hooks/` |
| An interface for one feature | `src/features/<feature>/types/` |
| An interface shared across features | `src/types/` |
| Supabase queries for a feature | `src/features/<feature>/services/` |
| The Supabase client factory | `src/lib/supabase/` |

---

## Supabase Conventions

Connects to the **same Supabase project** as the iOS app. The DB schema (tables `users`, `vehicles`, `bengkels`, `service_requests`, `mechanic_invitations`, `mechanic_resignations`, `vouchers`, `user_vouchers`) is documented in [`../CLAUDE.md`](../CLAUDE.md) — **treat that as the source of truth** and mirror it into `src/types/database.ts`.

### Setup (do this before writing data code)

```sh
pnpm add @supabase/supabase-js @supabase/ssr
```

Credentials go in `.env.local` (never hard-code them, never commit them):

```
NEXT_PUBLIC_SUPABASE_URL=https://ipxwpxozreksmuiztwcy.supabase.co
NEXT_PUBLIC_SUPABASE_ANON_KEY=<anon/publishable key>
```

### Client factories (`src/lib/supabase/`)

- **`server.ts`** — `createClient()` for Server Components, Server Actions, and Route Handlers. Reads cookies via `@supabase/ssr`. **Prefer this** — fetch data on the server.
- **`client.ts`** — `createClient()` for Client Components that genuinely need realtime or browser-side mutations.

### Data access pattern

All Supabase calls live in a feature's `services/` folder — components and pages never call `supabase.from(...)` inline. Services are typed functions that return typed rows; **no `any`**.

```ts
// src/features/bengkels/services/bengkel-service.ts
import { createClient } from "@/lib/supabase/server";
import type { Bengkel } from "@/features/bengkels/types/bengkel";

export async function fetchPendingBengkels(): Promise<Bengkel[]> {
  const supabase = await createClient();
  const { data, error } = await supabase
    .from("bengkels")
    .select("*")
    .eq("status", "Pending");

  if (error) throw error;
  return data;
}
```

### User ID convention

As in iOS, the user PK is the Supabase `auth.user.id` UUID **lowercased**. Use `.toLowerCase()` when filtering by user ID.

---

## Type Conventions

```ts
// src/features/bengkels/types/bengkel.ts
export interface Bengkel {
  id: string;
  providerUid: string;
  name: string;
  address: string;
  status: "Pending" | "Verified";
  averageRating: number | null;
  totalReviews: number | null;
}

// Component props — interface, in the feature's types/ folder
export interface BengkelTableProps {
  bengkels: Bengkel[];
  onVerify: (id: string) => void;
}
```

Rules:
- **No `any`** — ever. Use `unknown` + narrowing if a type is truly unknown.
- One concern per type file is ideal; grouping closely-related interfaces in a single feature type file is acceptable.
- DB row shapes mirror the Postgres columns from [`../CLAUDE.md`](../CLAUDE.md). Map snake_case columns to camelCase in the service layer (or keep snake_case consistently — pick one per feature and be consistent).
- Prefer string-literal unions over loose `string` for enum-like columns (`status`, `role`, `service_type`).

---

## Component Conventions

- **Server Component by default.** Only add `"use client"` when you need state, effects, event handlers, or browser APIs.
- Build from **shadcn/ui** primitives (`@/components/ui/*`). Compose, don't reinvent.
- Use `cn()` from `@/lib/utils` for conditional class merging.
- Props are always a named `interface` imported from a `types/` file (see rule 2).
- Keep pages (`app/**/page.tsx`) thin: fetch data (server-side) and compose feature components. Business logic lives in services/hooks.
- Use `sonner` (`toast(...)`) for user feedback; `lucide-react` for icons.

```tsx
// src/features/bengkels/components/bengkel-table.tsx
import { Table, TableBody, TableCell, TableRow } from "@/components/ui/table";
import { Badge } from "@/components/ui/badge";
import type { BengkelTableProps } from "@/features/bengkels/types/bengkel";

export function BengkelTable({ bengkels, onVerify }: BengkelTableProps) {
  return (
    <Table>
      <TableBody>
        {bengkels.map((b) => (
          <TableRow key={b.id}>
            <TableCell>{b.name}</TableCell>
            <TableCell>
              <Badge>{b.status}</Badge>
            </TableCell>
          </TableRow>
        ))}
      </TableBody>
    </Table>
  );
}
```

## Hook Conventions

- One custom hook per file, file named `use-<thing>.ts`, in the appropriate `hooks/` folder (global vs. feature).
- Hooks are Client-side (`"use client"` in the consuming component, not the hook file unless required).
- A hook owns its own typed state and returns a typed object — **no `any`**. Define the return-shape interface in a `types/` file when it is non-trivial.

```ts
// src/features/bengkels/hooks/use-pending-bengkels.ts
"use client";
import { useState, useEffect } from "react";
import type { Bengkel } from "@/features/bengkels/types/bengkel";
import { fetchPendingBengkelsClient } from "@/features/bengkels/services/bengkel-service";

export function usePendingBengkels() {
  const [bengkels, setBengkels] = useState<Bengkel[]>([]);
  const [isLoading, setIsLoading] = useState(true);

  useEffect(() => {
    fetchPendingBengkelsClient()
      .then(setBengkels)
      .finally(() => setIsLoading(false));
  }, []);

  return { bengkels, isLoading };
}
```

---

## Path Aliases

`@/*` → `src/*` (see `tsconfig.json`). Always import via aliases, never deep relative paths (`../../../`).

| Alias | Resolves to |
|-------|-------------|
| `@/components` | `src/components` |
| `@/components/ui` | `src/components/ui` (shadcn) |
| `@/hooks` | `src/hooks` |
| `@/lib` | `src/lib` |
| `@/lib/utils` | `cn()` helper |
| `@/types` | `src/types` |
| `@/features/<f>/...` | feature module |

---

## Definition of Done

- [ ] No `any` anywhere in the change.
- [ ] Every new interface/data-type lives in a `types/` folder, not inline.
- [ ] Every new hook lives in a `hooks/` folder, one per file.
- [ ] Feature code is under `src/features/<feature>/`; shared code is in the top-level folders.
- [ ] UI is built from shadcn/ui primitives.
- [ ] Supabase access is isolated in a `services/` file, not inline in components.
- [ ] `pnpm lint` and `pnpm build` pass clean.
