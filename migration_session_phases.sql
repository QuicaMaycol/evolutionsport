-- Migración para añadir fases a los ejercicios de la sesión
-- Esto permite categorizar los ejercicios en: 'warmup', 'main', 'cooldown'

DO $$ 
BEGIN 
    -- 1. Intentar añadir la columna 'phase' si no existe
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'evolutionsport' AND table_name = 'session_drills' AND column_name = 'phase') THEN
        ALTER TABLE evolutionsport.session_drills ADD COLUMN phase VARCHAR(20) DEFAULT 'main';
    END IF;

    -- 2. Asegurar que existe la tabla session_drills si no existía (Defensivo, basado en el código Dart)
    CREATE TABLE IF NOT EXISTS evolutionsport.session_drills (
        id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
        session_id UUID NOT NULL REFERENCES evolutionsport.sessions(id) ON DELETE CASCADE,
        drill_id UUID NOT NULL REFERENCES evolutionsport.drills(id) ON DELETE CASCADE,
        order_index INT NOT NULL DEFAULT 0,
        duration_minutes INT DEFAULT 15,
        phase VARCHAR(20) DEFAULT 'main', -- 'warmup', 'main', 'cooldown'
        created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    );
EXCEPTION
    WHEN duplicate_table THEN
        NULL; -- Ya existe
END $$;
