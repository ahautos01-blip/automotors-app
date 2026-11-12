-- Follow listing visibility without querying private profiles as the caller.
alter policy "AUTOMOTORS lectura fotos publicadas y reservadas" on storage.objects
using (bucket_id='vehicle-photos' and exists (
 select 1 from public.vehicle_listings l
 where l.id::text=split_part(storage.objects.name,'/',2)
 and l.owner_id::text=split_part(storage.objects.name,'/',1)
 and (l.status in ('published','reserved') or l.owner_id=(select auth.uid()))
));
