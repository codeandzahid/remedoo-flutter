-- Delivery orders: link to the REAL orders table + pharmacy access
-- (full-check fix, 2026-10-22).
--
-- delivery_orders.order_id pointed at remedoo_orders — a table the
-- app never writes (checkout writes to public.orders) — so no
-- delivery could ever be created and the driver panel stayed empty
-- forever. This migration:
--   1. re-points the FK at public.orders,
--   2. lets a pharmacy read/create/update delivery rows for its OWN
--      orders (the Assign Driver action in the pharmacy panel),
--   3. lets pharmacies read the active driver list to pick from,
--   4. re-points the patient read policy at public.orders.
-- Driver policies (read/update own assignments) are unchanged.

ALTER TABLE public.delivery_orders
  DROP CONSTRAINT IF EXISTS delivery_orders_order_id_fkey;
ALTER TABLE public.delivery_orders
  ADD CONSTRAINT delivery_orders_order_id_fkey
  FOREIGN KEY (order_id) REFERENCES public.orders(id) ON DELETE CASCADE;

DROP POLICY IF EXISTS "User reads own delivery orders" ON public.delivery_orders;
CREATE POLICY "User reads own delivery orders" ON public.delivery_orders
  FOR SELECT TO authenticated
  USING (order_id IN (SELECT id FROM public.orders WHERE user_id = auth.uid()));

DROP POLICY IF EXISTS "Pharmacy manages deliveries for own orders" ON public.delivery_orders;
CREATE POLICY "Pharmacy manages deliveries for own orders" ON public.delivery_orders
  FOR ALL TO authenticated
  USING (order_id IN (
    SELECT id FROM public.orders
     WHERE pharmacy_id IN (SELECT id FROM public.pharmacies WHERE user_id = auth.uid())))
  WITH CHECK (order_id IN (
    SELECT id FROM public.orders
     WHERE pharmacy_id IN (SELECT id FROM public.pharmacies WHERE user_id = auth.uid())));

DROP POLICY IF EXISTS "Pharmacies read active drivers" ON public.delivery_drivers;
CREATE POLICY "Pharmacies read active drivers" ON public.delivery_drivers
  FOR SELECT TO authenticated
  USING (is_active = true AND EXISTS (
    SELECT 1 FROM public.user_roles r
     WHERE r.user_id = auth.uid() AND r.role IN ('pharmacy', 'admin')));
