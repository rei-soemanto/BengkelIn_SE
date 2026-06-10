# BengkelIn — System Architecture

A whole-app architecture view: the **three deployables that share one Supabase project**, the iOS app's **layered MVVM** flow, the backend surface, and the external services. Rendered in plain **black & white**.

**Arrows**: solid `-->` = a call / data flow · dashed `-.->` = realtime subscription or async callback (webhook).

```mermaid
---
config:
  layout: elk
  theme: base
  themeVariables:
    primaryColor: '#ffffff'
    primaryBorderColor: '#000000'
    primaryTextColor: '#000000'
    lineColor: '#000000'
    textColor: '#000000'
---
flowchart TB
    subgraph IOS["iOS App — SwiftUI · Layered MVVM"]
        direction TB
        V["View<br/>Pages + Components (SwiftUI)"]
        VM["ViewModel<br/>@MainActor · ObservableObject · @Published"]
        REPO["Repository<br/>single-table CRUD + RPC"]
        SVC["Service<br/>Auth · Storage · Edge Fn · Photon · local notifications"]
        MOD["Models + DTOs<br/>Codable structs"]
        V -->|observe @Published| VM
        VM --> REPO
        VM --> SVC
        REPO -.->|decode| MOD
        SVC -.->|decode| MOD
    end

    subgraph WEB["Admin Web — Next.js 16 · App Router / RSC · TypeScript"]
        direction TB
        PAGE["Route / Page<br/>app/(admin)/* · Server Component (thin)"]
        COMP["Feature Component<br/>components/features/* · composed from shadcn/ui"]
        WHOOK["Hook<br/>client state (use client)"]
        WSVC["Service<br/>per-feature Supabase data access"]
        WCLI["Supabase client<br/>lib/supabase: client / server / proxy"]
        WTYPES["Types<br/>types/database.ts (mirrors schema)"]
        PAGE --> COMP
        COMP --> WHOOK
        COMP --> WSVC
        WHOOK --> WSVC
        WSVC --> WCLI
        WSVC -.->|typed by| WTYPES
    end

    subgraph SB["Supabase — shared backend project"]
        direction TB
        PG[("Postgres<br/>RLS · escrow triggers · RPCs")]
        AUTH["Auth<br/>sessions / JWT"]
        STG["Storage<br/>avatars · order-photos · chat-images"]
        RT["Realtime<br/>per-order / per-user channels"]
        EFB["Edge Fn: bidding"]
        EFP["Edge Fn: payment"]
        EFW["Edge Fn: midtrans-webhook"]
    end

    PHOTON["Photon / OSM<br/>geocoding + tiles"]
    MID["Midtrans<br/>Snap payments"]

    %% iOS data layer -> backend
    REPO -->|supabase.from / .rpc| PG
    SVC --> AUTH
    SVC --> STG
    SVC -->|BiddingService| EFB
    SVC -->|PaymentService| EFP
    SVC --> PHOTON

    %% realtime (ViewModel subscribes directly — the one sanctioned exception)
    VM -.->|subscribe| RT
    RT -.->|push row changes| VM

    %% admin web shares the same project
    WCLI -->|supabase-js / ssr| PG
    WCLI --> AUTH

    %% backend internal + external money flow
    EFB --> PG
    EFP --> PG
    EFP --> MID
    MID -.->|payment webhook| EFW
    EFW -->|settle_topup| PG
```

## How to read it

- **Three deployables, one backend.** The **iOS app** and the **Admin Web** are separate clients that talk to the **same Supabase project** — no separate API server; Supabase *is* the backend.
- **The MVVM rule (iOS):** `View → ViewModel → Repository | Service → Supabase`. ViewModels never touch Supabase directly **except realtime** — they subscribe to channels themselves (the dashed `ViewModel ↔ Realtime` link).
- **The web architecture (Admin):** feature-based Next.js App Router — `Route/Page (RSC) → Feature Component (shadcn/ui) → Hook | Service → Supabase client → Supabase`. Pages are thin (routing only); each feature owns its components/hooks/services/types under `components/features/<feature>/`; data access goes through the `lib/supabase` client factories (`client` for the browser, `server` for RSC). It's the web analogue of the iOS layering: **Component ≈ View, Hook+Service ≈ ViewModel+Repository, database.ts ≈ Models/DTOs.**
- **Repository vs Service:** Repositories do single-table CRUD + RPCs against Postgres (`supabase.from / .rpc`); Services do non-table work — Auth, Storage, the `bidding` / `payment` **edge functions**, Photon geocoding, and **local notifications** (`UNUserNotificationCenter`, fired on-device when realtime events arrive — no APNs / remote push).
- **Money is server-side.** The client never moves money: `PaymentService → payment` edge fn returns a Midtrans Snap URL; after the user pays, **Midtrans calls the `midtrans-webhook`** edge function, which alone runs `settle_topup` on Postgres. Escrow itself lives in Postgres **triggers**, not the client.
- **External services:** Photon/OSM (maps + geocoding) and Midtrans (payments) — only two. Notifications are local on-device, not a remote service.
