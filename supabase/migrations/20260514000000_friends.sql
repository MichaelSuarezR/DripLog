create table if not exists public.friendships (
  id uuid primary key default gen_random_uuid(),
  requester_id uuid not null references auth.users(id) on delete cascade,
  addressee_id uuid not null references auth.users(id) on delete cascade,
  status text not null default 'pending' check (status in ('pending', 'accepted')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint friendships_no_self_request check (requester_id <> addressee_id)
);

create unique index if not exists friendships_unique_directional
on public.friendships (requester_id, addressee_id);

alter table public.friendships enable row level security;

drop policy if exists "Authenticated users can read profiles" on public.profiles;
drop policy if exists "Authenticated users can read profile photos" on storage.objects;
drop policy if exists "Users can read their friendships" on public.friendships;
drop policy if exists "Users can send friend requests" on public.friendships;
drop policy if exists "Users can accept requests sent to them" on public.friendships;
drop policy if exists "Users can follow accounts" on public.friendships;
drop policy if exists "Users can delete their friendships" on public.friendships;

create policy "Authenticated users can read profiles"
on public.profiles
for select
to authenticated
using (true);

create policy "Authenticated users can read profile photos"
on storage.objects
for select
to authenticated
using (bucket_id = 'profile-photos');

create policy "Users can read their friendships"
on public.friendships
for select
to authenticated
using (requester_id = auth.uid() or addressee_id = auth.uid());

create policy "Users can follow accounts"
on public.friendships
for insert
to authenticated
with check (
  requester_id = auth.uid()
  and status = 'accepted'
  and requester_id <> addressee_id
);

create policy "Users can delete their friendships"
on public.friendships
for delete
to authenticated
using (requester_id = auth.uid() or addressee_id = auth.uid());
