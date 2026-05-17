drop policy if exists "Authenticated users can read outfit previews" on public.outfits;
drop policy if exists "Authenticated users can read outfit photos" on storage.objects;

create policy "Authenticated users can read outfit previews"
on public.outfits
for select
to authenticated
using (true);

create policy "Authenticated users can read outfit photos"
on storage.objects
for select
to authenticated
using (bucket_id = 'outfit-photos');
