-- 0. Create the schema if it doesn't exist
CREATE SCHEMA IF NOT EXISTS evolutionsport;

-- 1. Create academies table
CREATE TABLE evolutionsport.academies (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(255) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 2. Create profiles table (for users)
CREATE TABLE evolutionsport.profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    full_name VARCHAR(255),
    academy_id UUID REFERENCES evolutionsport.academies(id) ON DELETE SET NULL,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 3. Create players table
CREATE TABLE evolutionsport.players (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    first_name VARCHAR(255) NOT NULL,
    last_name VARCHAR(255) NOT NULL,
    position VARCHAR(100),
    sessions_completed INT NOT NULL DEFAULT 0,
    last_attendance TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    academy_id UUID NOT NULL REFERENCES evolutionsport.academies(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 4. Enable Row Level Security (RLS) for all tables
ALTER TABLE evolutionsport.academies ENABLE ROW LEVEL SECURITY;
ALTER TABLE evolutionsport.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE evolutionsport.players ENABLE ROW LEVEL SECURITY;

-- 5. RLS Policy for academies: Users can only see their own academy.
CREATE POLICY "Users can view their own academy"
ON evolutionsport.academies FOR SELECT
USING (id = (SELECT academy_id FROM evolutionsport.profiles WHERE id = auth.uid()));

-- 6. RLS Policy for profiles: Users can see all profiles in their academy.
CREATE POLICY "Users can view profiles in their academy"
ON evolutionsport.profiles FOR SELECT
USING (academy_id = (SELECT academy_id FROM evolutionsport.profiles WHERE id = auth.uid()));

-- 7. RLS Policy for players: Users can see all players in their academy.
CREATE POLICY "Users can view players in their academy"
ON evolutionsport.players FOR SELECT
USING (academy_id = (SELECT academy_id FROM evolutionsport.profiles WHERE id = auth.uid()));

-- 8. RLS Policy for players (INSERT): Users can only add players to their own academy.
CREATE POLICY "Users can insert players into their own academy"
ON evolutionsport.players FOR INSERT
WITH CHECK (academy_id = (SELECT academy_id FROM evolutionsport.profiles WHERE id = auth.uid()));

-- 9. RLS Policy for players (UPDATE): Users can only update players in their own academy.
CREATE POLICY "Users can update players in their own academy"
ON evolutionsport.players FOR UPDATE
USING (academy_id = (SELECT academy_id FROM evolutionsport.profiles WHERE id = auth.uid()));
