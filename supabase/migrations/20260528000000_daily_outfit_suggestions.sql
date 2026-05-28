create table if not exists public.daily_outfit_suggestions (
  user_id uuid not null references auth.users(id) on delete cascade,
  local_date date not null,
  left_outfit_id uuid not null references public.outfits(id) on delete cascade,
  right_outfit_id uuid not null references public.outfits(id) on delete cascade,
  inspiration jsonb not null,
  weather jsonb not null,
  explanation text not null,
  created_at timestamptz not null default now(),
  primary key (user_id, local_date)
);

alter table public.daily_outfit_suggestions enable row level security;

drop policy if exists "Users can read their daily outfit suggestions" on public.daily_outfit_suggestions;
drop policy if exists "Users can create their daily outfit suggestions" on public.daily_outfit_suggestions;
drop policy if exists "Users can update their daily outfit suggestions" on public.daily_outfit_suggestions;

create policy "Users can read their daily outfit suggestions"
on public.daily_outfit_suggestions
for select
to authenticated
using (user_id = auth.uid());

create policy "Users can create their daily outfit suggestions"
on public.daily_outfit_suggestions
for insert
to authenticated
with check (user_id = auth.uid());

create policy "Users can update their daily outfit suggestions"
on public.daily_outfit_suggestions
for update
to authenticated
using (user_id = auth.uid())
with check (user_id = auth.uid());
