insert into storage.buckets (id, name, public)
values ('outfit-photos', 'outfit-photos', false)
on conflict (id) do nothing;

alter table public.outfits enable row level security;

drop policy if exists "Users can read their outfits" on public.outfits;
drop policy if exists "Users can insert their outfits" on public.outfits;
drop policy if exists "Users can update their outfits" on public.outfits;
drop policy if exists "Users can delete their outfits" on public.outfits;

create policy "Users can read their outfits"
on public.outfits
for select
to authenticated
using (user_id = auth.uid());

create policy "Users can insert their outfits"
on public.outfits
for insert
to authenticated
with check (user_id = auth.uid());

create policy "Users can update their outfits"
on public.outfits
for update
to authenticated
using (user_id = auth.uid())
with check (user_id = auth.uid());

create policy "Users can delete their outfits"
on public.outfits
for delete
to authenticated
using (user_id = auth.uid());

drop policy if exists "Users can read their outfit photos" on storage.objects;
drop policy if exists "Users can insert their outfit photos" on storage.objects;
drop policy if exists "Users can update their outfit photos" on storage.objects;
drop policy if exists "Users can delete their outfit photos" on storage.objects;

create policy "Users can read their outfit photos"
on storage.objects
for select
to authenticated
using (
  bucket_id = 'outfit-photos'
  and (storage.foldername(name))[1] = auth.uid()::text
);

create policy "Users can insert their outfit photos"
on storage.objects
for insert
to authenticated
with check (
  bucket_id = 'outfit-photos'
  and (storage.foldername(name))[1] = auth.uid()::text
);

create policy "Users can update their outfit photos"
on storage.objects
for update
to authenticated
using (
  bucket_id = 'outfit-photos'
  and (storage.foldername(name))[1] = auth.uid()::text
)
with check (
  bucket_id = 'outfit-photos'
  and (storage.foldername(name))[1] = auth.uid()::text
);

create policy "Users can delete their outfit photos"
on storage.objects
for delete
to authenticated
using (
  bucket_id = 'outfit-photos'
  and (storage.foldername(name))[1] = auth.uid()::text
);
