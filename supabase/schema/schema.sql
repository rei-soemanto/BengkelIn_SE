CREATE TYPE public."BengkelStatus" AS ENUM ('Pending', 'Verified', 'Rejected');

CREATE TYPE public."RegistrationStatus" AS ENUM ('Pending', 'Rejected', 'Accepted');

CREATE TABLE public.behavior_reports (
    id uuid NOT NULL DEFAULT gen_random_uuid(),
    service_request_id uuid NOT NULL,
    reporter_id uuid NOT NULL,
    reason text NOT NULL,
    created_at timestamp with time zone NOT NULL DEFAULT now(),
    status text NOT NULL DEFAULT 'pending'::text,
    resolved_at timestamp with time zone
);

CREATE TABLE public.bengkels (
    id uuid NOT NULL DEFAULT gen_random_uuid(),
    provider_uid uuid,
    name text NOT NULL,
    address text NOT NULL,
    latitude double precision NOT NULL,
    longitude double precision NOT NULL,
    status "BengkelStatus" NOT NULL DEFAULT 'Pending'::"BengkelStatus",
    average_rating double precision NOT NULL DEFAULT 0.0,
    total_reviews integer NOT NULL DEFAULT 0,
    created_at timestamp with time zone DEFAULT now(),
    offered_services jsonb
);

CREATE TABLE public.bids (
    id uuid NOT NULL DEFAULT gen_random_uuid(),
    service_request_id uuid NOT NULL,
    provider_uid uuid NOT NULL,
    bengkel_id uuid NOT NULL,
    price bigint NOT NULL,
    notes text,
    status text NOT NULL DEFAULT 'pending'::text,
    created_at timestamp with time zone NOT NULL DEFAULT now()
);

CREATE TABLE public.chat_messages (
    id uuid NOT NULL DEFAULT gen_random_uuid(),
    service_request_id uuid NOT NULL,
    sender_id uuid NOT NULL,
    content text,
    image_url text,
    created_at timestamp with time zone NOT NULL DEFAULT now()
);

CREATE TABLE public.customer_locations (
    service_request_id uuid NOT NULL,
    customer_id uuid NOT NULL,
    latitude double precision NOT NULL,
    longitude double precision NOT NULL,
    updated_at timestamp with time zone NOT NULL DEFAULT now()
);

CREATE TABLE public.mechanic_registrations (
    id uuid NOT NULL DEFAULT gen_random_uuid(),
    bengkel_id uuid DEFAULT gen_random_uuid(),
    mechanic_id uuid DEFAULT gen_random_uuid(),
    status "RegistrationStatus" DEFAULT 'Pending'::"RegistrationStatus",
    created_at timestamp with time zone NOT NULL DEFAULT now()
);

CREATE TABLE public.order_disputes (
    id uuid NOT NULL DEFAULT gen_random_uuid(),
    service_request_id uuid NOT NULL,
    initiated_by uuid NOT NULL,
    initiator_role text NOT NULL,
    reason text NOT NULL,
    proof_url text,
    status text NOT NULL DEFAULT 'pending'::text,
    created_at timestamp with time zone NOT NULL DEFAULT now(),
    resolved_at timestamp with time zone
);

CREATE TABLE public.order_locations (
    service_request_id uuid NOT NULL,
    provider_uid uuid NOT NULL,
    latitude double precision NOT NULL,
    longitude double precision NOT NULL,
    updated_at timestamp with time zone NOT NULL DEFAULT now()
);

CREATE TABLE public.platform_revenue (
    id uuid NOT NULL DEFAULT gen_random_uuid(),
    service_request_id uuid NOT NULL,
    gross_amount numeric NOT NULL,
    fee_amount numeric NOT NULL,
    points_redeemed integer NOT NULL DEFAULT 0,
    points_earned integer NOT NULL DEFAULT 0,
    net_revenue numeric NOT NULL,
    created_at timestamp with time zone NOT NULL DEFAULT now()
);

CREATE TABLE public.service_requests (
    id uuid NOT NULL DEFAULT gen_random_uuid(),
    customer_id uuid NOT NULL,
    bengkel_id uuid,
    mechanic_id uuid,
    service_type text NOT NULL,
    description text,
    status text DEFAULT 'pending'::text,
    is_emergency boolean DEFAULT false,
    location text,
    latitude double precision,
    longitude double precision,
    price bigint,
    mechanic_notes text,
    assigned_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    vehicle_id uuid,
    customer_completed boolean NOT NULL DEFAULT false,
    provider_completed boolean NOT NULL DEFAULT false,
    completion_photo_url text,
    completed_at timestamp with time zone,
    rating integer,
    tire_count integer NOT NULL DEFAULT 1,
    photo_urls jsonb NOT NULL DEFAULT '[]'::jsonb,
    vehicle_info text,
    use_points boolean NOT NULL DEFAULT false,
    points_used integer NOT NULL DEFAULT 0,
    points_earned integer NOT NULL DEFAULT 0,
    first_completed_at timestamp with time zone
);

CREATE TABLE public.topups (
    id uuid NOT NULL DEFAULT gen_random_uuid(),
    user_id uuid NOT NULL,
    order_id text NOT NULL,
    gross_amount double precision NOT NULL,
    status text NOT NULL DEFAULT 'pending'::text,
    payment_type text,
    redirect_url text,
    snap_token text,
    created_at timestamp with time zone NOT NULL DEFAULT now(),
    updated_at timestamp with time zone NOT NULL DEFAULT now()
);

CREATE TABLE public.users (
    id uuid NOT NULL,
    name text NOT NULL,
    profile_image_url text,
    balance double precision NOT NULL DEFAULT 0.0,
    role text NOT NULL DEFAULT 'USER'::text,
    held_balance double precision NOT NULL DEFAULT 0,
    pending_balance double precision NOT NULL DEFAULT 0,
    bank_name text,
    bank_account_number text,
    bank_account_name text,
    points integer NOT NULL DEFAULT 0,
    pending_points integer NOT NULL DEFAULT 0
);

CREATE TABLE public.vehicles (
    id uuid NOT NULL DEFAULT gen_random_uuid(),
    customer_id uuid,
    manufacturer text NOT NULL,
    model text NOT NULL,
    year integer NOT NULL,
    license_plate text NOT NULL,
    color text NOT NULL,
    created_at timestamp with time zone DEFAULT now()
);

CREATE TABLE public.withdrawals (
    id uuid NOT NULL DEFAULT gen_random_uuid(),
    user_id uuid NOT NULL,
    amount double precision NOT NULL,
    bank_name text,
    bank_account_number text,
    bank_account_name text,
    status text NOT NULL DEFAULT 'pending'::text,
    notes text,
    created_at timestamp with time zone NOT NULL DEFAULT now(),
    updated_at timestamp with time zone NOT NULL DEFAULT now()
);

ALTER TABLE public.behavior_reports ADD CONSTRAINT behavior_reports_pkey PRIMARY KEY (id);

ALTER TABLE public.behavior_reports ADD CONSTRAINT behavior_reports_status_check CHECK ((status = ANY (ARRAY['pending'::text, 'refunded'::text, 'paid'::text])));

ALTER TABLE public.bengkels ADD CONSTRAINT bengkels_pkey PRIMARY KEY (id);

ALTER TABLE public.bids ADD CONSTRAINT bids_pkey PRIMARY KEY (id);

ALTER TABLE public.bids ADD CONSTRAINT bids_service_request_id_provider_uid_key UNIQUE (service_request_id, provider_uid);

ALTER TABLE public.chat_messages ADD CONSTRAINT chat_messages_content_or_image CHECK (((content IS NOT NULL) OR (image_url IS NOT NULL)));

ALTER TABLE public.chat_messages ADD CONSTRAINT chat_messages_pkey PRIMARY KEY (id);

ALTER TABLE public.customer_locations ADD CONSTRAINT customer_locations_pkey PRIMARY KEY (service_request_id);

ALTER TABLE public.mechanic_registrations ADD CONSTRAINT mechanic_registrations_pkey PRIMARY KEY (id);

ALTER TABLE public.order_disputes ADD CONSTRAINT order_disputes_initiator_role_check CHECK ((initiator_role = ANY (ARRAY['customer'::text, 'provider'::text])));

ALTER TABLE public.order_disputes ADD CONSTRAINT order_disputes_pkey PRIMARY KEY (id);

ALTER TABLE public.order_disputes ADD CONSTRAINT order_disputes_status_check CHECK ((status = ANY (ARRAY['pending'::text, 'refunded'::text, 'paid'::text])));

ALTER TABLE public.order_locations ADD CONSTRAINT order_locations_pkey PRIMARY KEY (service_request_id);

ALTER TABLE public.platform_revenue ADD CONSTRAINT platform_revenue_pkey PRIMARY KEY (id);

ALTER TABLE public.platform_revenue ADD CONSTRAINT platform_revenue_service_request_id_key UNIQUE (service_request_id);

ALTER TABLE public.service_requests ADD CONSTRAINT service_requests_pkey PRIMARY KEY (id);

ALTER TABLE public.service_requests ADD CONSTRAINT service_requests_rating_range CHECK (((rating IS NULL) OR ((rating >= 1) AND (rating <= 5))));

ALTER TABLE public.topups ADD CONSTRAINT topups_order_id_key UNIQUE (order_id);

ALTER TABLE public.topups ADD CONSTRAINT topups_pkey PRIMARY KEY (id);

ALTER TABLE public.users ADD CONSTRAINT users_pkey PRIMARY KEY (id);

ALTER TABLE public.vehicles ADD CONSTRAINT vehicles_pkey PRIMARY KEY (id);

ALTER TABLE public.withdrawals ADD CONSTRAINT withdrawals_pkey PRIMARY KEY (id);

CREATE UNIQUE INDEX behavior_reports_unique_reporter_per_request ON public.behavior_reports USING btree (service_request_id, reporter_id);

CREATE INDEX bids_provider_uid_idx ON public.bids USING btree (provider_uid);

CREATE INDEX chat_messages_request_idx ON public.chat_messages USING btree (service_request_id, created_at);

CREATE INDEX idx_sr_bengkel ON public.service_requests USING btree (bengkel_id);

CREATE INDEX idx_sr_customer ON public.service_requests USING btree (customer_id);

CREATE INDEX idx_sr_mechanic ON public.service_requests USING btree (mechanic_id);

CREATE INDEX idx_sr_status ON public.service_requests USING btree (status);

CREATE INDEX order_disputes_request_idx ON public.order_disputes USING btree (service_request_id);

CREATE INDEX platform_revenue_created_idx ON public.platform_revenue USING btree (created_at);

CREATE INDEX topups_user_id_idx ON public.topups USING btree (user_id);

CREATE INDEX withdrawals_user_id_idx ON public.withdrawals USING btree (user_id);

ALTER TABLE public.behavior_reports ADD CONSTRAINT behavior_reports_reporter_id_fkey FOREIGN KEY (reporter_id) REFERENCES users(id) ON DELETE CASCADE;

ALTER TABLE public.behavior_reports ADD CONSTRAINT behavior_reports_service_request_id_fkey FOREIGN KEY (service_request_id) REFERENCES service_requests(id) ON DELETE CASCADE;

ALTER TABLE public.bengkels ADD CONSTRAINT bengkels_provider_uid_fkey FOREIGN KEY (provider_uid) REFERENCES users(id) ON DELETE CASCADE;

ALTER TABLE public.bids ADD CONSTRAINT bids_bengkel_id_fkey FOREIGN KEY (bengkel_id) REFERENCES bengkels(id) ON DELETE CASCADE;

ALTER TABLE public.bids ADD CONSTRAINT bids_provider_uid_fkey FOREIGN KEY (provider_uid) REFERENCES users(id) ON DELETE CASCADE;

ALTER TABLE public.bids ADD CONSTRAINT bids_service_request_id_fkey FOREIGN KEY (service_request_id) REFERENCES service_requests(id) ON DELETE CASCADE;

ALTER TABLE public.chat_messages ADD CONSTRAINT chat_messages_sender_id_fkey FOREIGN KEY (sender_id) REFERENCES users(id);

ALTER TABLE public.chat_messages ADD CONSTRAINT chat_messages_service_request_id_fkey FOREIGN KEY (service_request_id) REFERENCES service_requests(id) ON DELETE CASCADE;

ALTER TABLE public.customer_locations ADD CONSTRAINT customer_locations_customer_id_fkey FOREIGN KEY (customer_id) REFERENCES users(id) ON DELETE CASCADE;

ALTER TABLE public.customer_locations ADD CONSTRAINT customer_locations_service_request_id_fkey FOREIGN KEY (service_request_id) REFERENCES service_requests(id) ON DELETE CASCADE;

ALTER TABLE public.mechanic_registrations ADD CONSTRAINT mechanic_registrations_bengkel_id_fkey FOREIGN KEY (bengkel_id) REFERENCES bengkels(id) ON UPDATE CASCADE ON DELETE CASCADE;

ALTER TABLE public.mechanic_registrations ADD CONSTRAINT mechanic_registrations_mechanic_id_fkey FOREIGN KEY (mechanic_id) REFERENCES auth.users(id) ON UPDATE CASCADE ON DELETE CASCADE;

ALTER TABLE public.order_disputes ADD CONSTRAINT order_disputes_initiated_by_fkey FOREIGN KEY (initiated_by) REFERENCES users(id);

ALTER TABLE public.order_disputes ADD CONSTRAINT order_disputes_service_request_id_fkey FOREIGN KEY (service_request_id) REFERENCES service_requests(id) ON DELETE CASCADE;

ALTER TABLE public.order_locations ADD CONSTRAINT order_locations_provider_uid_fkey FOREIGN KEY (provider_uid) REFERENCES users(id) ON DELETE CASCADE;

ALTER TABLE public.order_locations ADD CONSTRAINT order_locations_service_request_id_fkey FOREIGN KEY (service_request_id) REFERENCES service_requests(id) ON DELETE CASCADE;

ALTER TABLE public.platform_revenue ADD CONSTRAINT platform_revenue_service_request_id_fkey FOREIGN KEY (service_request_id) REFERENCES service_requests(id) ON DELETE CASCADE;

ALTER TABLE public.service_requests ADD CONSTRAINT service_requests_bengkel_id_fkey FOREIGN KEY (bengkel_id) REFERENCES bengkels(id);

ALTER TABLE public.service_requests ADD CONSTRAINT service_requests_customer_id_fkey FOREIGN KEY (customer_id) REFERENCES users(id);

ALTER TABLE public.service_requests ADD CONSTRAINT service_requests_mechanic_id_fkey FOREIGN KEY (mechanic_id) REFERENCES users(id);

ALTER TABLE public.service_requests ADD CONSTRAINT service_requests_vehicle_id_fkey FOREIGN KEY (vehicle_id) REFERENCES vehicles(id);

ALTER TABLE public.topups ADD CONSTRAINT topups_user_id_fkey FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE;

ALTER TABLE public.users ADD CONSTRAINT users_id_fkey FOREIGN KEY (id) REFERENCES auth.users(id) ON DELETE CASCADE;

ALTER TABLE public.vehicles ADD CONSTRAINT vehicles_customer_id_fkey FOREIGN KEY (customer_id) REFERENCES users(id) ON DELETE CASCADE;

ALTER TABLE public.withdrawals ADD CONSTRAINT withdrawals_user_id_fkey FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE;

ALTER TABLE public.behavior_reports ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.bengkels ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.bids ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.chat_messages ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.customer_locations ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.mechanic_registrations ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.order_disputes ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.order_locations ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.platform_revenue ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.service_requests ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.topups ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.vehicles ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.withdrawals ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Admins cannot register bengkels" ON public.bengkels AS RESTRICTIVE FOR INSERT TO authenticated WITH CHECK ((( SELECT users.role
   FROM users
  WHERE (users.id = auth.uid())) IS DISTINCT FROM 'ADMIN'::text));

CREATE POLICY "Admins read platform revenue" ON public.platform_revenue AS PERMISSIVE FOR SELECT TO public USING ((EXISTS ( SELECT 1
   FROM users u
  WHERE ((u.id = auth.uid()) AND (u.role = 'ADMIN'::text)))));

CREATE POLICY "Anyone can view bengkels." ON public.bengkels AS PERMISSIVE FOR SELECT TO public USING (true);

CREATE POLICY "Authenticated can view open service requests" ON public.service_requests AS PERMISSIVE FOR SELECT TO authenticated USING (((status = 'pending'::text) AND (bengkel_id IS NULL)));

CREATE POLICY "Bengkels can view their service requests" ON public.service_requests AS PERMISSIVE FOR SELECT TO authenticated USING ((bengkel_id IN ( SELECT bengkels.id
   FROM bengkels
  WHERE (bengkels.provider_uid = auth.uid()))));

CREATE POLICY "Customers can insert their requests" ON public.service_requests AS PERMISSIVE FOR INSERT TO public WITH CHECK ((customer_id = auth.uid()));

CREATE POLICY "Customers can view their requests" ON public.service_requests AS PERMISSIVE FOR SELECT TO public USING ((customer_id = auth.uid()));

CREATE POLICY "Customers insert their order location" ON public.customer_locations AS PERMISSIVE FOR INSERT TO public WITH CHECK ((auth.uid() = customer_id));

CREATE POLICY "Customers update bids on their requests" ON public.bids AS PERMISSIVE FOR UPDATE TO authenticated USING ((EXISTS ( SELECT 1
   FROM service_requests sr
  WHERE ((sr.id = bids.service_request_id) AND (sr.customer_id = auth.uid()))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM service_requests sr
  WHERE ((sr.id = bids.service_request_id) AND (sr.customer_id = auth.uid())))));

CREATE POLICY "Customers update their order location" ON public.customer_locations AS PERMISSIVE FOR UPDATE TO public USING ((auth.uid() = customer_id)) WITH CHECK ((auth.uid() = customer_id));

CREATE POLICY "Customers view bids on their requests" ON public.bids AS PERMISSIVE FOR SELECT TO authenticated USING ((EXISTS ( SELECT 1
   FROM service_requests sr
  WHERE ((sr.id = bids.service_request_id) AND (sr.customer_id = auth.uid())))));

CREATE POLICY "Enable read access for all authenticated users" ON public.users AS PERMISSIVE FOR SELECT TO authenticated USING (true);

CREATE POLICY "Mechanics can view their assigned requests" ON public.service_requests AS PERMISSIVE FOR SELECT TO public USING ((mechanic_id = auth.uid()));

CREATE POLICY "Order parties insert reports" ON public.behavior_reports AS PERMISSIVE FOR INSERT TO public WITH CHECK (((auth.uid() = reporter_id) AND ((EXISTS ( SELECT 1
   FROM service_requests sr
  WHERE ((sr.id = behavior_reports.service_request_id) AND (sr.customer_id = auth.uid())))) OR (EXISTS ( SELECT 1
   FROM (service_requests sr
     JOIN bengkels b ON ((b.id = sr.bengkel_id)))
  WHERE ((sr.id = behavior_reports.service_request_id) AND (b.provider_uid = auth.uid())))))));

CREATE POLICY "Order parties read customer location" ON public.customer_locations AS PERMISSIVE FOR SELECT TO authenticated USING (((auth.uid() = customer_id) OR (EXISTS ( SELECT 1
   FROM service_requests sr
  WHERE ((sr.id = customer_locations.service_request_id) AND ((sr.mechanic_id = auth.uid()) OR (EXISTS ( SELECT 1
           FROM bengkels b
          WHERE ((b.id = sr.bengkel_id) AND (b.provider_uid = auth.uid()))))))))));

CREATE POLICY "Order parties read live location" ON public.order_locations AS PERMISSIVE FOR SELECT TO authenticated USING (((auth.uid() = provider_uid) OR (EXISTS ( SELECT 1
   FROM service_requests sr
  WHERE ((sr.id = order_locations.service_request_id) AND ((sr.customer_id = auth.uid()) OR (sr.mechanic_id = auth.uid()) OR (EXISTS ( SELECT 1
           FROM bengkels b
          WHERE ((b.id = sr.bengkel_id) AND (b.provider_uid = auth.uid()))))))))));

CREATE POLICY "Order parties view disputes" ON public.order_disputes AS PERMISSIVE FOR SELECT TO public USING (((auth.uid() = initiated_by) OR (EXISTS ( SELECT 1
   FROM service_requests sr
  WHERE ((sr.id = order_disputes.service_request_id) AND (sr.customer_id = auth.uid())))) OR (EXISTS ( SELECT 1
   FROM (service_requests sr
     JOIN bengkels b ON ((b.id = sr.bengkel_id)))
  WHERE ((sr.id = order_disputes.service_request_id) AND (b.provider_uid = auth.uid()))))));

CREATE POLICY "Participants send messages" ON public.chat_messages AS PERMISSIVE FOR INSERT TO authenticated WITH CHECK (((sender_id = auth.uid()) AND (EXISTS ( SELECT 1
   FROM service_requests sr
  WHERE ((sr.id = chat_messages.service_request_id) AND (sr.status = ANY (ARRAY['pending'::text, 'accepted'::text, 'in_progress'::text])) AND ((sr.customer_id = auth.uid()) OR (sr.mechanic_id = auth.uid())))))));

CREATE POLICY "Participants view messages" ON public.chat_messages AS PERMISSIVE FOR SELECT TO authenticated USING ((EXISTS ( SELECT 1
   FROM service_requests sr
  WHERE ((sr.id = chat_messages.service_request_id) AND ((sr.customer_id = auth.uid()) OR (sr.mechanic_id = auth.uid()) OR (EXISTS ( SELECT 1
           FROM bengkels b
          WHERE ((b.id = sr.bengkel_id) AND (b.provider_uid = auth.uid())))))))));

CREATE POLICY "Providers can manage their own bengkels." ON public.bengkels AS PERMISSIVE FOR ALL TO public USING ((auth.uid() = provider_uid));

CREATE POLICY "Providers insert own bids" ON public.bids AS PERMISSIVE FOR INSERT TO authenticated WITH CHECK (((auth.uid() = provider_uid) AND (EXISTS ( SELECT 1
   FROM ((service_requests sr
     JOIN bengkels b ON (((b.id = bids.bengkel_id) AND (b.provider_uid = auth.uid()))))
     CROSS JOIN LATERAL jsonb_array_elements(b.offered_services) svc(value))
  WHERE ((sr.id = bids.service_request_id) AND ((svc.value ->> 'service_type'::text) = sr.service_type) AND COALESCE(((svc.value ->> 'is_active'::text))::boolean, true))))));

CREATE POLICY "Providers insert their order location" ON public.order_locations AS PERMISSIVE FOR INSERT TO public WITH CHECK ((auth.uid() = provider_uid));

CREATE POLICY "Providers update own bids" ON public.bids AS PERMISSIVE FOR UPDATE TO authenticated USING ((auth.uid() = provider_uid)) WITH CHECK ((auth.uid() = provider_uid));

CREATE POLICY "Providers update their order location" ON public.order_locations AS PERMISSIVE FOR UPDATE TO public USING ((auth.uid() = provider_uid)) WITH CHECK ((auth.uid() = provider_uid));

CREATE POLICY "Providers view own bids" ON public.bids AS PERMISSIVE FOR SELECT TO authenticated USING ((auth.uid() = provider_uid));

CREATE POLICY "Reporters view own reports" ON public.behavior_reports AS PERMISSIVE FOR SELECT TO public USING ((auth.uid() = reporter_id));

CREATE POLICY "Users can manage their own vehicles." ON public.vehicles AS PERMISSIVE FOR ALL TO public USING ((auth.uid() = customer_id));

CREATE POLICY "Users can view and update own profile." ON public.users AS PERMISSIVE FOR ALL TO public USING ((auth.uid() = id));

CREATE POLICY mr_select_mechanic ON public.mechanic_registrations AS PERMISSIVE FOR SELECT TO authenticated USING ((mechanic_id = auth.uid()));

CREATE POLICY mr_select_provider ON public.mechanic_registrations AS PERMISSIVE FOR SELECT TO authenticated USING ((bengkel_id IN ( SELECT bengkels.id
   FROM bengkels
  WHERE (bengkels.provider_uid = auth.uid()))));

CREATE POLICY topups_select_own ON public.topups AS PERMISSIVE FOR SELECT TO public USING ((auth.uid() = user_id));

CREATE POLICY withdrawals_select_own ON public.withdrawals AS PERMISSIVE FOR SELECT TO public USING ((auth.uid() = user_id));

ALTER PUBLICATION supabase_realtime ADD TABLE public.bengkels;

ALTER PUBLICATION supabase_realtime ADD TABLE public.bids;

ALTER PUBLICATION supabase_realtime ADD TABLE public.chat_messages;

ALTER PUBLICATION supabase_realtime ADD TABLE public.customer_locations;

ALTER PUBLICATION supabase_realtime ADD TABLE public.order_locations;

ALTER PUBLICATION supabase_realtime ADD TABLE public.service_requests;

ALTER PUBLICATION supabase_realtime ADD TABLE public.topups;

ALTER PUBLICATION supabase_realtime ADD TABLE public.withdrawals;
