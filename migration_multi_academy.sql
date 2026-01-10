-- 1. Crear tabla de relación Muchos-a-Muchos
CREATE TABLE IF NOT EXISTS evolutionsport.coach_academies (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    coach_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    academy_id UUID NOT NULL REFERENCES evolutionsport.academies(id) ON DELETE CASCADE,
    role VARCHAR(50) DEFAULT 'coach', -- 'admin', 'coach', 'assistant'
    is_active BOOLEAN DEFAULT TRUE,
    joined_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(coach_id, academy_id) -- Un entrenador no puede estar duplicado en la misma academia
);

-- 2. Habilitar RLS
ALTER TABLE evolutionsport.coach_academies ENABLE ROW LEVEL SECURITY;

-- 3. Políticas para coach_academies
-- El entrenador puede ver sus propias afiliaciones
CREATE POLICY "Users can view their own memberships"
ON evolutionsport.coach_academies FOR SELECT
USING (coach_id = auth.uid());

-- 4. MIGRACIÓN DE DATOS (Crucial para no romper lo actual)
-- Insertar en la nueva tabla basándonos en la relación actual en 'profiles'
INSERT INTO evolutionsport.coach_academies (coach_id, academy_id, role)
SELECT id, academy_id, role
FROM evolutionsport.profiles
WHERE academy_id IS NOT NULL
ON CONFLICT (coach_id, academy_id) DO NOTHING;

-- 5. ACTUALIZAR POLÍTICAS EXISTENTES (El cambio grande)

-- ACADEMIAS: Ahora puedes ver una academia si estás en la tabla coach_academies
DROP POLICY IF EXISTS "Users can view their own academy" ON evolutionsport.academies;
CREATE POLICY "Users can view their academies"
ON evolutionsport.academies FOR SELECT
USING (
    id IN (
        SELECT academy_id 
        FROM evolutionsport.coach_academies 
        WHERE coach_id = auth.uid() AND is_active = TRUE
    )
);

-- JUGADORES: Puedes ver jugadores si pertenecen a una academia donde tú eres miembro activo
DROP POLICY IF EXISTS "Users can view players in their academy" ON evolutionsport.players;
CREATE POLICY "Users can view players in their academies"
ON evolutionsport.players FOR SELECT
USING (
    academy_id IN (
        SELECT academy_id 
        FROM evolutionsport.coach_academies 
        WHERE coach_id = auth.uid() AND is_active = TRUE
    )
);

-- (Repetir lógica para INSERT/UPDATE de jugadores si es necesario,
--  pero por ahora SELECT es lo crítico para visualizar)

-- NOTA: No borramos la columna 'academy_id' de profiles todavía.
-- La usaremos como "Academia Seleccionada Actualmente" (Contexto de Sesión) en la App.
