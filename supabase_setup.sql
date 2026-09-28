-- Run this SQL in the Supabase SQL Editor to create the necessary tables for Kalori Matik

create table profiles (
  id uuid references auth.users on delete cascade primary key,
  age integer,
  gender text,
  height numeric,
  weight numeric,
  activity_level numeric,
  goal text,
  daily_tdee integer,
  target_weight_loss numeric,
  target_days integer,
  role varchar(20) default 'client',
  kalori_id varchar(10) unique
);

create table meal_logs (
  id uuid default gen_random_uuid() primary key,
  user_id uuid references profiles(id) on delete cascade not null,
  name text not null,
  calories integer not null,
  insight text,
  protein numeric,
  carbs numeric,
  fat numeric,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

create table connections (
  id uuid default gen_random_uuid() primary key,
  professional_id uuid references auth.users(id) on delete cascade not null,
  client_id uuid references auth.users(id) on delete cascade not null,
  status varchar(20) default 'active',
  created_at timestamp with time zone default timezone('utc'::text, now()) not null,
  unique(professional_id, client_id)
);

-- Turn on Row Level Security
alter table profiles enable row level security;
alter table meal_logs enable row level security;
alter table connections enable row level security;

-- Create Policies to allow users to read and write only their own data
create policy "Users can view own profile" 
  on profiles for select 
  using ( auth.uid() = id );

create policy "Users can insert their own profile" 
  on profiles for insert 
  with check ( auth.uid() = id );

create policy "Users can update own profile" 
  on profiles for update 
  using ( auth.uid() = id );

create policy "Users can view own meal logs" 
  on meal_logs for select 
  using ( auth.uid() = user_id );

create policy "Users can insert own meal logs" 
  on meal_logs for insert 
  with check ( auth.uid() = user_id );

create policy "Professionals can view their connections" 
  on connections for select 
  using ( auth.uid() = professional_id OR auth.uid() = client_id );

create policy "Professionals can insert connections" 
  on connections for insert 
  with check ( auth.uid() = professional_id );
