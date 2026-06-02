-- APPLIED 2026-06-03 to project ipxwpxozreksmuiztwcy.
-- Role-based tracking: the bengkel's provider must be able to read the assigned mechanic's
-- live location (order_locations) for their bengkel's order, so the provider can monitor the
-- mechanic + customer. Previously only the row's publisher and the customer could read it,
-- which blocked the provider's monitoring view.
drop policy if exists "Order parties read live location" on public.order_locations;
create policy "Order parties read live location" on public.order_locations for select to authenticated
using (
  auth.uid() = provider_uid
  or exists (
    select 1 from public.service_requests sr
    where sr.id = order_locations.service_request_id
      and ( sr.customer_id = auth.uid()
         or sr.mechanic_id = auth.uid()
         or exists (select 1 from public.bengkels b where b.id = sr.bengkel_id and b.provider_uid = auth.uid()) )
  )
);
