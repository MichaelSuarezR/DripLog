drop index if exists public.friendships_unique_pair;

create unique index if not exists friendships_unique_directional
on public.friendships (requester_id, addressee_id);

insert into public.friendships (requester_id, addressee_id, status)
select addressee_id, requester_id, 'accepted'
from public.friendships
where status = 'accepted'
on conflict (requester_id, addressee_id) do nothing;

update public.friendships
set status = 'accepted'
where status = 'pending';

drop policy if exists "Users can send friend requests" on public.friendships;
drop policy if exists "Users can accept requests sent to them" on public.friendships;
drop policy if exists "Users can follow accounts" on public.friendships;

create policy "Users can follow accounts"
on public.friendships
for insert
to authenticated
with check (
  requester_id = auth.uid()
  and status = 'accepted'
  and requester_id <> addressee_id
);

drop policy if exists "Authenticated users can read outfit previews" on public.outfits;

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
