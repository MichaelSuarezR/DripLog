alter table public.outfits
add column if not exists visibility text not null default 'public'
check (visibility in ('private', 'friends', 'public'));

alter table public.outfits
alter column visibility set default 'public';

update public.outfits
set visibility = 'public'
where visibility is null or visibility = 'private';

create table if not exists public.outfit_bookmarks (
  user_id uuid not null references auth.users(id) on delete cascade,
  outfit_id uuid not null references public.outfits(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_id, outfit_id)
);

create table if not exists public.outfit_likes (
  user_id uuid not null references auth.users(id) on delete cascade,
  outfit_id uuid not null references public.outfits(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_id, outfit_id)
);

alter table public.outfit_bookmarks enable row level security;
alter table public.outfit_likes enable row level security;

drop policy if exists "Users can read their outfit bookmarks" on public.outfit_bookmarks;
drop policy if exists "Users can create their outfit bookmarks" on public.outfit_bookmarks;
drop policy if exists "Users can delete their outfit bookmarks" on public.outfit_bookmarks;
drop policy if exists "Users can read their outfit likes" on public.outfit_likes;
drop policy if exists "Users can create their outfit likes" on public.outfit_likes;
drop policy if exists "Users can delete their outfit likes" on public.outfit_likes;
drop policy if exists "Authenticated users can read outfit previews" on public.outfits;

create policy "Users can read their outfit bookmarks"
on public.outfit_bookmarks
for select
to authenticated
using (user_id = auth.uid());

create policy "Users can create their outfit bookmarks"
on public.outfit_bookmarks
for insert
to authenticated
with check (user_id = auth.uid());

create policy "Users can delete their outfit bookmarks"
on public.outfit_bookmarks
for delete
to authenticated
using (user_id = auth.uid());

create policy "Users can read their outfit likes"
on public.outfit_likes
for select
to authenticated
using (
  user_id = auth.uid()
  or exists (
    select 1
    from public.outfits o
    where o.id = outfit_likes.outfit_id
      and o.user_id = auth.uid()
  )
);

create policy "Users can create their outfit likes"
on public.outfit_likes
for insert
to authenticated
with check (user_id = auth.uid());

create policy "Users can delete their outfit likes"
on public.outfit_likes
for delete
to authenticated
using (user_id = auth.uid());

create policy "Authenticated users can read outfit previews"
on public.outfits
for select
to authenticated
using (
  visibility = 'public'
  or user_id = auth.uid()
  or exists (
    select 1
    from public.friendships outgoing
    join public.friendships incoming
      on incoming.requester_id = outfits.user_id
      and incoming.addressee_id = auth.uid()
      and incoming.status = 'accepted'
    where outgoing.status = 'accepted'
      and visibility = 'friends'
      and outgoing.requester_id = auth.uid()
      and outgoing.addressee_id = outfits.user_id
  )
  or exists (
    select 1
    from public.outfit_bookmarks b
    where b.user_id = auth.uid()
      and b.outfit_id = outfits.id
  )
);
