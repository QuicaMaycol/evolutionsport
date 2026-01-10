-- 0. Create the schema if it doesn't exist
CREATE SCHEMA IF NOT EXISTS evolutionsport;

-- 1. Create academies table
CREATE TABLE IF NOT EXISTS evolutionsport.academies (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(255) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 2. Create profiles table (for users)
CREATE TABLE IF NOT EXISTS evolutionsport.profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    full_name VARCHAR(255),
    academy_id UUID REFERENCES evolutionsport.academies(id) ON DELETE SET NULL,
    is_freelancer BOOLEAN DEFAULT FALSE,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 3. Create players table
CREATE TABLE IF NOT EXISTS evolutionsport.players (
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

-- 4. Create templates table (Tactics/Sessions to be sold or used)
CREATE TABLE IF NOT EXISTS evolutionsport.templates (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    title VARCHAR(255) NOT NULL,
    description TEXT,
    content JSONB, -- Stores the actual tactical data/layout
    price DECIMAL(10, 2) DEFAULT 0, -- For selling
    is_for_sale BOOLEAN DEFAULT FALSE, -- Listed in marketplace
    creator_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    academy_id UUID REFERENCES evolutionsport.academies(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 5. Enable Row Level Security (RLS) for all tables
ALTER TABLE evolutionsport.academies ENABLE ROW LEVEL SECURITY;
ALTER TABLE evolutionsport.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE evolutionsport.players ENABLE ROW LEVEL SECURITY;
ALTER TABLE evolutionsport.templates ENABLE ROW LEVEL SECURITY;

-- 6. RLS Policies

-- Academies
DROP POLICY IF EXISTS "Users can view their own academy" ON evolutionsport.academies;
CREATE POLICY "Users can view their own academy"
ON evolutionsport.academies FOR SELECT
USING (id = (SELECT academy_id FROM evolutionsport.profiles WHERE id = auth.uid()));

-- Profiles
DROP POLICY IF EXISTS "Users can view profiles in their academy" ON evolutionsport.profiles;
CREATE POLICY "Users can view profiles in their academy"
ON evolutionsport.profiles FOR SELECT
USING (academy_id = (SELECT academy_id FROM evolutionsport.profiles WHERE id = auth.uid()));

DROP POLICY IF EXISTS "Users can update their own profile" ON evolutionsport.profiles;
CREATE POLICY "Users can update their own profile"
ON evolutionsport.profiles FOR UPDATE
USING (id = auth.uid());

-- Players
DROP POLICY IF EXISTS "Users can view players in their academy" ON evolutionsport.players;
CREATE POLICY "Users can view players in their academy"
ON evolutionsport.players FOR SELECT
USING (academy_id = (SELECT academy_id FROM evolutionsport.profiles WHERE id = auth.uid()));

DROP POLICY IF EXISTS "Users can insert players into their own academy" ON evolutionsport.players;
CREATE POLICY "Users can insert players into their own academy"
ON evolutionsport.players FOR INSERT
WITH CHECK (academy_id = (SELECT academy_id FROM evolutionsport.profiles WHERE id = auth.uid()));

DROP POLICY IF EXISTS "Users can update players in their own academy" ON evolutionsport.players;
CREATE POLICY "Users can update players in their own academy"
ON evolutionsport.players FOR UPDATE
USING (academy_id = (SELECT academy_id FROM evolutionsport.profiles WHERE id = auth.uid()));

-- Templates Policies (Crucial for Freelancers & Marketplace)

-- View: Own templates OR Academy templates OR Templates for sale (Marketplace)
DROP POLICY IF EXISTS "Users can view relevant templates" ON evolutionsport.templates;
CREATE POLICY "Users can view relevant templates"
ON evolutionsport.templates FOR SELECT
USING (
    creator_id = auth.uid() OR 
    (academy_id = (SELECT academy_id FROM evolutionsport.profiles WHERE id = auth.uid()) AND academy_id IS NOT NULL) OR
    is_for_sale = TRUE
);

-- Insert: Authenticated users can create templates
DROP POLICY IF EXISTS "Users can create templates" ON evolutionsport.templates;
CREATE POLICY "Users can create templates"
ON evolutionsport.templates FOR INSERT
WITH CHECK (creator_id = auth.uid());

-- Update: Only the creator can update their templates
DROP POLICY IF EXISTS "Creators can update their templates" ON evolutionsport.templates;
CREATE POLICY "Creators can update their templates"
ON evolutionsport.templates FOR UPDATE
USING (creator_id = auth.uid());

-- Delete: Only the creator can delete their templates
DROP POLICY IF EXISTS "Creators can delete their templates" ON evolutionsport.templates;
CREATE POLICY "Creators can delete their templates"
ON evolutionsport.templates FOR DELETE
USING (creator_id = auth.uid());
