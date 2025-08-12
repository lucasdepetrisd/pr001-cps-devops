-- #############################################################################
-- # Esquema de Base de Datos para el sistema 'db-cps'                         #
-- # Motor: PostgreSQL                                                       #
-- # Autor: Moreno                                                           #
-- # Versión: 1.3 (Ajustado para base de datos preexistente)                   #
-- #############################################################################

-- ========= CREACIÓN DEL ESQUEMA =========

-- Se crea un esquema general 'cps' para alojar todos los módulos del sistema.
-- Este comando no generará un error si el esquema ya existe.
CREATE SCHEMA IF NOT EXISTS cps;
SET search_path TO cps;


-- ========= TABLAS DE CATÁLOGO (reemplazan a los ENUMs) =========
-- Estas tablas almacenan los valores que antes estaban en tipos ENUM,
-- permitiendo una gestión más flexible.

CREATE TABLE tipos_unidad_valor (
    id SMALLSERIAL PRIMARY KEY,
    nombre VARCHAR(50) UNIQUE NOT NULL
);
INSERT INTO tipos_unidad_valor (nombre) VALUES ('MRS'), ('VAR');

CREATE TABLE tipos_afiliado (
    id SMALLSERIAL PRIMARY KEY,
    nombre VARCHAR(50) UNIQUE NOT NULL
);
INSERT INTO tipos_afiliado (nombre) VALUES ('OBLIGATORIO'), ('VOLUNTARIO'), ('VOLUNTARIO_TRANSICIONAL');

CREATE TABLE estados_afiliado (
    id SMALLSERIAL PRIMARY KEY,
    nombre VARCHAR(50) UNIQUE NOT NULL
);
INSERT INTO estados_afiliado (nombre) VALUES ('ACTIVO'), ('ACTIVO_CON_EXENCION'), ('AUTOBLOQUEADO'), ('SUSPENDIDO'), ('BAJA_CANCELADO'), ('FALLECIDO'), ('JUBILADO'), ('PENDIENTE_APROBACION'), ('RECHAZADO');

CREATE TABLE tipos_cuenta_capitalizacion (
    id SMALLSERIAL PRIMARY KEY,
    nombre VARCHAR(50) UNIQUE NOT NULL
);
INSERT INTO tipos_cuenta_capitalizacion (nombre) VALUES ('CIAO'), ('CIAV'), ('CIAVF');

CREATE TABLE estados_beneficio_pension (
    id SMALLSERIAL PRIMARY KEY,
    nombre VARCHAR(50) UNIQUE NOT NULL
);
INSERT INTO estados_beneficio_pension (nombre) VALUES ('ACTIVO'), ('BENEFICIO_EXTINGUIDO');

CREATE TABLE tipos_cambio_historial (
    id SMALLSERIAL PRIMARY KEY,
    nombre VARCHAR(20) UNIQUE NOT NULL
);
INSERT INTO tipos_cambio_historial (nombre) VALUES ('INSERT'), ('UPDATE'), ('DELETE');


-- ========= FUNCIÓN GENÉRICA PARA ACTUALIZAR `fecha_modificacion` =========

CREATE OR REPLACE FUNCTION fn_actualizar_fecha_modificacion()
RETURNS TRIGGER AS $$
BEGIN
    NEW.fecha_modificacion = now();
    RETURN NEW;
END;
$$ language 'plpgsql';


-- ========================================================================
-- TABLA 1: Usuarios
-- ========================================================================

CREATE TABLE usuarios (
    id SERIAL PRIMARY KEY,
    nombre_usuario VARCHAR(100) NOT NULL UNIQUE,
    rol VARCHAR(50) NOT NULL,
    activo BOOLEAN NOT NULL DEFAULT true,
    fecha_creacion TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    fecha_modificacion TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    fecha_baja TIMESTAMPTZ NULL,
    usuario_creacion INT NULL REFERENCES usuarios(id) DEFERRABLE INITIALLY DEFERRED,
    usuario_modificacion INT NULL REFERENCES usuarios(id) DEFERRABLE INITIALLY DEFERRED,
    usuario_baja INT NULL REFERENCES usuarios(id),
    observaciones TEXT NULL
);
COMMENT ON TABLE usuarios IS 'Almacena los usuarios del sistema y sus roles.';
CREATE TRIGGER trg_usuarios_fecha_modificacion BEFORE UPDATE ON usuarios FOR EACH ROW EXECUTE FUNCTION fn_actualizar_fecha_modificacion();


-- ========================================================================
-- TABLA 2: Unidades_Valor
-- ========================================================================

CREATE TABLE unidades_valor (
    id SERIAL PRIMARY KEY,
    tipo_unidad_valor_id SMALLINT NOT NULL REFERENCES tipos_unidad_valor(id),
    valor DECIMAL(18, 2) NOT NULL,
    fecha_vigencia_desde DATE NOT NULL,
    fecha_vigencia_hasta DATE NULL,
    activo BOOLEAN NOT NULL DEFAULT true,
    fecha_creacion TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    fecha_modificacion TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    fecha_baja TIMESTAMPTZ NULL,
    usuario_creacion INT NOT NULL REFERENCES usuarios(id),
    usuario_modificacion INT NOT NULL REFERENCES usuarios(id),
    usuario_baja INT NULL REFERENCES usuarios(id),
    observaciones TEXT NULL,
    UNIQUE (tipo_unidad_valor_id, fecha_vigencia_desde)
);
COMMENT ON TABLE unidades_valor IS 'Valores históricos y vigentes de las unidades de medida como MRS y VAR.';
CREATE TRIGGER trg_unidades_valor_fecha_modificacion BEFORE UPDATE ON unidades_valor FOR EACH ROW EXECUTE FUNCTION fn_actualizar_fecha_modificacion();


-- ========================================================================
-- TABLA 3: Afiliados
-- ========================================================================

CREATE TABLE afiliados (
    id SERIAL PRIMARY KEY,
    n_legajo VARCHAR(20) UNIQUE NOT NULL,
    n_matricula VARCHAR(20) NULL,
    tipo_afiliado_id SMALLINT NOT NULL REFERENCES tipos_afiliado(id),
    estado_afiliado_id SMALLINT NOT NULL REFERENCES estados_afiliado(id),
    apellidos VARCHAR(100) NOT NULL,
    nombres VARCHAR(100) NOT NULL,
    nacionalidad VARCHAR(50) NULL,
    documento_tipo VARCHAR(10) NULL,
    documento_numero VARCHAR(20) NULL,
    cuit BIGINT UNIQUE NOT NULL,
    fecha_nacimiento DATE NOT NULL,
    estado_civil VARCHAR(50) NULL,
    titulo_profesional VARCHAR(100) NULL,
    fecha_graduacion DATE NULL,
    domicilio_calle VARCHAR(100) NULL,
    domicilio_numero VARCHAR(10) NULL,
    domicilio_piso VARCHAR(10) NULL,
    domicilio_depto VARCHAR(10) NULL,
    domicilio_localidad VARCHAR(100) NULL,
    domicilio_provincia VARCHAR(100) NULL,
    domicilio_cp VARCHAR(10) NULL,
    telefono VARCHAR(50) NULL,
    email_caja VARCHAR(255) NOT NULL,
    email_consejo VARCHAR(255) NULL,
    delegacion VARCHAR(100) NULL,
    declaracion_salud_preexistente BOOLEAN NOT NULL,
    declaracion_salud_aclaraciones TEXT NULL,
    fecha_alta_efectiva DATE NULL,
    fecha_inicio_actividad_aporte DATE NULL,
    fecha_fin_exencion DATE NULL,
    fecha_matriculacion DATE NULL,
    activo BOOLEAN NOT NULL DEFAULT true,
    fecha_creacion TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    fecha_modificacion TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    fecha_baja TIMESTAMPTZ NULL,
    usuario_creacion INT NOT NULL REFERENCES usuarios(id),
    usuario_modificacion INT NOT NULL REFERENCES usuarios(id),
    usuario_baja INT NULL REFERENCES usuarios(id),
    observaciones TEXT NULL
);
COMMENT ON TABLE afiliados IS 'Tabla central con los datos personales y de afiliación.';
CREATE TRIGGER trg_afiliados_fecha_modificacion BEFORE UPDATE ON afiliados FOR EACH ROW EXECUTE FUNCTION fn_actualizar_fecha_modificacion();


-- ========================================================================
-- TABLA 3.1: Afiliados_historial y su Trigger
-- ========================================================================

CREATE TABLE afiliados_historial (
    id_historial SERIAL PRIMARY KEY,
    registro_id INT NOT NULL,
    n_legajo VARCHAR(20) NOT NULL,
    n_matricula VARCHAR(20) NULL,
    tipo_afiliado_id SMALLINT NOT NULL,
    estado_afiliado_id SMALLINT NOT NULL,
    apellidos VARCHAR(100) NOT NULL,
    nombres VARCHAR(100) NOT NULL,
    nacionalidad VARCHAR(50) NULL,
    documento_tipo VARCHAR(10) NULL,
    documento_numero VARCHAR(20) NULL,
    cuit BIGINT NOT NULL,
    fecha_nacimiento DATE NOT NULL,
    estado_civil VARCHAR(50) NULL,
    titulo_profesional VARCHAR(100) NULL,
    fecha_graduacion DATE NULL,
    domicilio_calle VARCHAR(100) NULL,
    domicilio_numero VARCHAR(10) NULL,
    domicilio_piso VARCHAR(10) NULL,
    domicilio_depto VARCHAR(10) NULL,
    domicilio_localidad VARCHAR(100) NULL,
    domicilio_provincia VARCHAR(100) NULL,
    domicilio_cp VARCHAR(10) NULL,
    telefono VARCHAR(50) NULL,
    email_caja VARCHAR(255) NOT NULL,
    email_consejo VARCHAR(255) NULL,
    delegacion VARCHAR(100) NULL,
    declaracion_salud_preexistente BOOLEAN NOT NULL,
    declaracion_salud_aclaraciones TEXT NULL,
    fecha_alta_efectiva DATE NULL,
    fecha_inicio_actividad_aporte DATE NULL,
    fecha_fin_exencion DATE NULL,
    fecha_matriculacion DATE NULL,
    activo BOOLEAN NOT NULL,
    observaciones TEXT NULL,
    fecha_cambio TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    usuario_cambio INT NOT NULL REFERENCES usuarios(id),
    tipo_cambio_id SMALLINT NOT NULL REFERENCES tipos_cambio_historial(id)
);
COMMENT ON TABLE afiliados_historial IS 'Tabla de auditoría para la tabla afiliados. Registra todos los cambios.';

CREATE OR REPLACE FUNCTION fn_afiliados_historial()
RETURNS TRIGGER AS $$
DECLARE
    v_record_to_log afiliados%ROWTYPE;
    v_usuario_cambio INT;
    v_tipo_cambio_id INT;
BEGIN
    SELECT id INTO v_tipo_cambio_id FROM tipos_cambio_historial WHERE nombre = TG_OP;
    IF (TG_OP = 'INSERT') THEN
        v_record_to_log := NEW;
        v_usuario_cambio := NEW.usuario_creacion;
    ELSIF (TG_OP = 'UPDATE') THEN
        v_record_to_log := NEW;
        v_usuario_cambio := NEW.usuario_modificacion;
    ELSIF (TG_OP = 'DELETE') THEN
        v_record_to_log := OLD;
        SELECT usuario_baja INTO v_usuario_cambio FROM afiliados WHERE id = OLD.id;
        IF v_usuario_cambio IS NULL THEN v_usuario_cambio := OLD.usuario_modificacion; END IF;
    END IF;

    INSERT INTO afiliados_historial (
        registro_id, n_legajo, n_matricula, tipo_afiliado_id, estado_afiliado_id, apellidos, nombres,
        nacionalidad, documento_tipo, documento_numero, cuit, fecha_nacimiento, estado_civil,
        titulo_profesional, fecha_graduacion, domicilio_calle, domicilio_numero, domicilio_piso,
        domicilio_depto, domicilio_localidad, domicilio_provincia, domicilio_cp, telefono,
        email_caja, email_consejo, delegacion, declaracion_salud_preexistente,
        declaracion_salud_aclaraciones, fecha_alta_efectiva, fecha_inicio_actividad_aporte,
        fecha_fin_exencion, fecha_matriculacion, activo, observaciones,
        fecha_cambio, usuario_cambio, tipo_cambio_id
    ) VALUES (
        v_record_to_log.id, v_record_to_log.n_legajo, v_record_to_log.n_matricula, v_record_to_log.tipo_afiliado_id,
        v_record_to_log.estado_afiliado_id, v_record_to_log.apellidos, v_record_to_log.nombres,
        v_record_to_log.nacionalidad, v_record_to_log.documento_tipo, v_record_to_log.documento_numero,
        v_record_to_log.cuit, v_record_to_log.fecha_nacimiento, v_record_to_log.estado_civil,
        v_record_to_log.titulo_profesional, v_record_to_log.fecha_graduacion, v_record_to_log.domicilio_calle,
        v_record_to_log.domicilio_numero, v_record_to_log.domicilio_piso, v_record_to_log.domicilio_depto,
        v_record_to_log.domicilio_localidad, v_record_to_log.domicilio_provincia, v_record_to_log.domicilio_cp,
        v_record_to_log.telefono, v_record_to_log.email_caja, v_record_to_log.email_consejo,
        v_record_to_log.delegacion, v_record_to_log.declaracion_salud_preexistente,
        v_record_to_log.declaracion_salud_aclaraciones, v_record_to_log.fecha_alta_efectiva,
        v_record_to_log.fecha_inicio_actividad_aporte, v_record_to_log.fecha_fin_exencion,
        v_record_to_log.fecha_matriculacion, v_record_to_log.activo, v_record_to_log.observaciones,
        CURRENT_TIMESTAMP, v_usuario_cambio, v_tipo_cambio_id
    );
    RETURN v_record_to_log;
END;
$$ language 'plpgsql';

CREATE TRIGGER trg_afiliados_historial AFTER INSERT OR UPDATE OR DELETE ON afiliados FOR EACH ROW EXECUTE FUNCTION fn_afiliados_historial();


-- ========================================================================
-- TABLA 4: Grupo_Familiar
-- ========================================================================

CREATE TABLE grupo_familiar (
    id SERIAL PRIMARY KEY,
    afiliado_id INT NOT NULL REFERENCES afiliados(id) ON DELETE CASCADE,
    apellidos VARCHAR(100) NOT NULL,
    nombres VARCHAR(100) NOT NULL,
    parentesco VARCHAR(50) NOT NULL,
    documento_tipo VARCHAR(10) NULL,
    documento_numero VARCHAR(20) NULL,
    fecha_nacimiento DATE NOT NULL,
    hijo_estudiante BOOLEAN NULL,
    hijo_incapacitado BOOLEAN NULL,
    activo BOOLEAN NOT NULL DEFAULT true,
    fecha_creacion TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    fecha_modificacion TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    fecha_baja TIMESTAMPTZ NULL,
    usuario_creacion INT NOT NULL REFERENCES usuarios(id),
    usuario_modificacion INT NOT NULL REFERENCES usuarios(id),
    usuario_baja INT NULL REFERENCES usuarios(id),
    observaciones TEXT NULL
);
COMMENT ON TABLE grupo_familiar IS 'Miembros del grupo familiar asociados a un afiliado.';
CREATE TRIGGER trg_grupo_familiar_fecha_modificacion BEFORE UPDATE ON grupo_familiar FOR EACH ROW EXECUTE FUNCTION fn_actualizar_fecha_modificacion();


-- ========================================================================
-- TABLA 4.1: Grupo_Familiar_historial y su Trigger
-- ========================================================================

CREATE TABLE grupo_familiar_historial (
    id_historial SERIAL PRIMARY KEY,
    registro_id INT NOT NULL,
    afiliado_id INT NOT NULL,
    apellidos VARCHAR(100) NOT NULL,
    nombres VARCHAR(100) NOT NULL,
    parentesco VARCHAR(50) NOT NULL,
    documento_tipo VARCHAR(10) NULL,
    documento_numero VARCHAR(20) NULL,
    fecha_nacimiento DATE NOT NULL,
    hijo_estudiante BOOLEAN NULL,
    hijo_incapacitado BOOLEAN NULL,
    activo BOOLEAN NOT NULL,
    observaciones TEXT NULL,
    fecha_cambio TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    usuario_cambio INT NOT NULL REFERENCES usuarios(id),
    tipo_cambio_id SMALLINT NOT NULL REFERENCES tipos_cambio_historial(id)
);
COMMENT ON TABLE grupo_familiar_historial IS 'Tabla de auditoría para grupo_familiar.';

CREATE OR REPLACE FUNCTION fn_grupo_familiar_historial()
RETURNS TRIGGER AS $$
DECLARE
    v_record_to_log grupo_familiar%ROWTYPE;
    v_usuario_cambio INT;
    v_tipo_cambio_id INT;
BEGIN
    SELECT id INTO v_tipo_cambio_id FROM tipos_cambio_historial WHERE nombre = TG_OP;
    IF (TG_OP = 'INSERT') THEN
        v_record_to_log := NEW;
        v_usuario_cambio := NEW.usuario_creacion;
    ELSIF (TG_OP = 'UPDATE') THEN
        v_record_to_log := NEW;
        v_usuario_cambio := NEW.usuario_modificacion;
    ELSIF (TG_OP = 'DELETE') THEN
        v_record_to_log := OLD;
        v_usuario_cambio := OLD.usuario_modificacion;
    END IF;

    INSERT INTO grupo_familiar_historial (
        registro_id, afiliado_id, apellidos, nombres, parentesco, documento_tipo,
        documento_numero, fecha_nacimiento, hijo_estudiante, hijo_incapacitado,
        activo, observaciones, fecha_cambio, usuario_cambio, tipo_cambio_id
    ) VALUES (
        v_record_to_log.id, v_record_to_log.afiliado_id, v_record_to_log.apellidos, v_record_to_log.nombres,
        v_record_to_log.parentesco, v_record_to_log.documento_tipo, v_record_to_log.documento_numero,
        v_record_to_log.fecha_nacimiento, v_record_to_log.hijo_estudiante, v_record_to_log.hijo_incapacitado,
        v_record_to_log.activo, v_record_to_log.observaciones,
        CURRENT_TIMESTAMP, v_usuario_cambio, v_tipo_cambio_id
    );
    RETURN v_record_to_log;
END;
$$ language 'plpgsql';

CREATE TRIGGER trg_grupo_familiar_historial AFTER INSERT OR UPDATE OR DELETE ON grupo_familiar FOR EACH ROW EXECUTE FUNCTION fn_grupo_familiar_historial();


-- ========================================================================
-- TABLA 5: Afiliado_Cuentas_Capitalizacion
-- ========================================================================

CREATE TABLE afiliado_cuentas_capitalizacion (
    id SERIAL PRIMARY KEY,
    afiliado_id INT NOT NULL REFERENCES afiliados(id) ON DELETE RESTRICT,
    tipo_cuenta_id SMALLINT NOT NULL REFERENCES tipos_cuenta_capitalizacion(id),
    saldo_actual DECIMAL(18, 2) NOT NULL DEFAULT 0.00,
    activo BOOLEAN NOT NULL DEFAULT true,
    fecha_creacion TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    fecha_modificacion TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    fecha_baja TIMESTAMPTZ NULL,
    usuario_creacion INT NOT NULL REFERENCES usuarios(id),
    usuario_modificacion INT NOT NULL REFERENCES usuarios(id),
    usuario_baja INT NULL REFERENCES usuarios(id),
    observaciones TEXT NULL,
    UNIQUE (afiliado_id, tipo_cuenta_id)
);
COMMENT ON TABLE afiliado_cuentas_capitalizacion IS 'Cuentas de capitalización (CIAO, CIAV, etc.) por afiliado.';
CREATE TRIGGER trg_cuentas_capitalizacion_fecha_modificacion BEFORE UPDATE ON afiliado_cuentas_capitalizacion FOR EACH ROW EXECUTE FUNCTION fn_actualizar_fecha_modificacion();


-- ========================================================================
-- TABLA 5.1: Afiliado_Cuentas_Capitalizacion_historial y su Trigger
-- ========================================================================

CREATE TABLE afiliado_cuentas_capitalizacion_historial (
    id_historial SERIAL PRIMARY KEY,
    registro_id INT NOT NULL,
    afiliado_id INT NOT NULL,
    tipo_cuenta_id SMALLINT NOT NULL,
    saldo_actual DECIMAL(18, 2) NOT NULL,
    activo BOOLEAN NOT NULL,
    observaciones TEXT NULL,
    fecha_cambio TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    usuario_cambio INT NOT NULL REFERENCES usuarios(id),
    tipo_cambio_id SMALLINT NOT NULL REFERENCES tipos_cambio_historial(id)
);
COMMENT ON TABLE afiliado_cuentas_capitalizacion_historial IS 'Tabla de auditoría para las cuentas de capitalización.';

CREATE OR REPLACE FUNCTION fn_afiliado_cuentas_capitalizacion_historial()
RETURNS TRIGGER AS $$
DECLARE
    v_record_to_log afiliado_cuentas_capitalizacion%ROWTYPE;
    v_usuario_cambio INT;
    v_tipo_cambio_id INT;
BEGIN
    SELECT id INTO v_tipo_cambio_id FROM tipos_cambio_historial WHERE nombre = TG_OP;
    IF (TG_OP = 'INSERT') THEN
        v_record_to_log := NEW;
        v_usuario_cambio := NEW.usuario_creacion;
    ELSIF (TG_OP = 'UPDATE') THEN
        v_record_to_log := NEW;
        v_usuario_cambio := NEW.usuario_modificacion;
    ELSIF (TG_OP = 'DELETE') THEN
        v_record_to_log := OLD;
        v_usuario_cambio := OLD.usuario_modificacion;
    END IF;

    INSERT INTO afiliado_cuentas_capitalizacion_historial (
        registro_id, afiliado_id, tipo_cuenta_id, saldo_actual, activo,
        observaciones, fecha_cambio, usuario_cambio, tipo_cambio_id
    ) VALUES (
        v_record_to_log.id, v_record_to_log.afiliado_id, v_record_to_log.tipo_cuenta_id, v_record_to_log.saldo_actual,
        v_record_to_log.activo, v_record_to_log.observaciones,
        CURRENT_TIMESTAMP, v_usuario_cambio, v_tipo_cambio_id
    );
    RETURN v_record_to_log;
END;
$$ language 'plpgsql';

CREATE TRIGGER trg_afiliado_cuentas_capitalizacion_historial AFTER INSERT OR UPDATE OR DELETE ON afiliado_cuentas_capitalizacion FOR EACH ROW EXECUTE FUNCTION fn_afiliado_cuentas_capitalizacion_historial();


-- ========================================================================
-- TABLA 6: Pensionados
-- ========================================================================

CREATE TABLE pensionados (
    id SERIAL PRIMARY KEY,
    afiliado_causante_id INT NOT NULL REFERENCES afiliados(id),
    apellidos VARCHAR(100) NOT NULL,
    nombres VARCHAR(100) NOT NULL,
    parentesco VARCHAR(50) NOT NULL,
    documento_tipo VARCHAR(10) NULL,
    documento_numero VARCHAR(20) NULL,
    fecha_nacimiento DATE NOT NULL,
    porcentaje_haber DECIMAL(5, 2) NOT NULL,
    monto_haber_inicial DECIMAL(18, 2) NOT NULL,
    fecha_alta_beneficio DATE NOT NULL,
    estado_beneficio_id SMALLINT NOT NULL REFERENCES estados_beneficio_pension(id),
    activo BOOLEAN NOT NULL DEFAULT true,
    fecha_creacion TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    fecha_modificacion TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    fecha_baja TIMESTAMPTZ NULL,
    usuario_creacion INT NOT NULL REFERENCES usuarios(id),
    usuario_modificacion INT NOT NULL REFERENCES usuarios(id),
    usuario_baja INT NULL REFERENCES usuarios(id),
    observaciones TEXT NULL
);
COMMENT ON TABLE pensionados IS 'Beneficiarios de pensiones por un afiliado causante.';
CREATE TRIGGER trg_pensionados_fecha_modificacion BEFORE UPDATE ON pensionados FOR EACH ROW EXECUTE FUNCTION fn_actualizar_fecha_modificacion();


-- ========================================================================
-- TABLA 6.1: Pensionados_historial y su Trigger
-- ========================================================================

CREATE TABLE pensionados_historial (
    id_historial SERIAL PRIMARY KEY,
    registro_id INT NOT NULL,
    afiliado_causante_id INT NOT NULL,
    apellidos VARCHAR(100) NOT NULL,
    nombres VARCHAR(100) NOT NULL,
    parentesco VARCHAR(50) NOT NULL,
    documento_tipo VARCHAR(10) NULL,
    documento_numero VARCHAR(20) NULL,
    fecha_nacimiento DATE NOT NULL,
    porcentaje_haber DECIMAL(5, 2) NOT NULL,
    monto_haber_inicial DECIMAL(18, 2) NOT NULL,
    fecha_alta_beneficio DATE NOT NULL,
    estado_beneficio_id SMALLINT NOT NULL,
    activo BOOLEAN NOT NULL,
    observaciones TEXT NULL,
    fecha_cambio TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    usuario_cambio INT NOT NULL REFERENCES usuarios(id),
    tipo_cambio_id SMALLINT NOT NULL REFERENCES tipos_cambio_historial(id)
);
COMMENT ON TABLE pensionados_historial IS 'Tabla de auditoría para pensionados.';

CREATE OR REPLACE FUNCTION fn_pensionados_historial()
RETURNS TRIGGER AS $$
DECLARE
    v_record_to_log pensionados%ROWTYPE;
    v_usuario_cambio INT;
    v_tipo_cambio_id INT;
BEGIN
    SELECT id INTO v_tipo_cambio_id FROM tipos_cambio_historial WHERE nombre = TG_OP;
    IF (TG_OP = 'INSERT') THEN
        v_record_to_log := NEW;
        v_usuario_cambio := NEW.usuario_creacion;
    ELSIF (TG_OP = 'UPDATE') THEN
        v_record_to_log := NEW;
        v_usuario_cambio := NEW.usuario_modificacion;
    ELSIF (TG_OP = 'DELETE') THEN
        v_record_to_log := OLD;
        v_usuario_cambio := OLD.usuario_modificacion;
    END IF;

    INSERT INTO pensionados_historial (
        registro_id, afiliado_causante_id, apellidos, nombres, parentesco, documento_tipo,
        documento_numero, fecha_nacimiento, porcentaje_haber, monto_haber_inicial,
        fecha_alta_beneficio, estado_beneficio_id, activo, observaciones,
        fecha_cambio, usuario_cambio, tipo_cambio_id
    ) VALUES (
        v_record_to_log.id, v_record_to_log.afiliado_causante_id, v_record_to_log.apellidos, v_record_to_log.nombres,
        v_record_to_log.parentesco, v_record_to_log.documento_tipo, v_record_to_log.documento_numero,
        v_record_to_log.fecha_nacimiento, v_record_to_log.porcentaje_haber, v_record_to_log.monto_haber_inicial,
        v_record_to_log.fecha_alta_beneficio, v_record_to_log.estado_beneficio_id, v_record_to_log.activo,
        v_record_to_log.observaciones, CURRENT_TIMESTAMP, v_usuario_cambio, v_tipo_cambio_id
    );
    RETURN v_record_to_log;
END;
$$ language 'plpgsql';

CREATE TRIGGER trg_pensionados_historial AFTER INSERT OR UPDATE OR DELETE ON pensionados FOR EACH ROW EXECUTE FUNCTION fn_pensionados_historial();


-- ========================================================================
-- TABLA 7: Bitacora_Logs
-- ========================================================================

CREATE TABLE bitacora_logs (
    id SERIAL PRIMARY KEY,
    usuario_id INT NULL REFERENCES usuarios(id),
    accion VARCHAR(50) NOT NULL,
    tabla VARCHAR(50) NULL,
    registro_id INT NULL,
    descripcion TEXT NOT NULL,
    fecha_hora TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    direccion_ip VARCHAR(45) NULL,
    navegador_cliente VARCHAR(255) NULL
);
COMMENT ON TABLE bitacora_logs IS 'Bitácora de eventos de alto nivel de la aplicación (logins, acciones críticas, etc.).';


-- ========= ÍNDICES PARA MEJORAR EL RENDIMIENTO DE LAS CONSULTAS =========

CREATE INDEX idx_afiliados_n_legajo ON afiliados(n_legajo);
CREATE INDEX idx_afiliados_cuit ON afiliados(cuit);
CREATE INDEX idx_afiliados_apellidos_nombres ON afiliados(apellidos, nombres);
CREATE INDEX idx_grupo_familiar_afiliado_id ON grupo_familiar(afiliado_id);
CREATE INDEX idx_pensionados_afiliado_causante_id ON pensionados(afiliado_causante_id);
CREATE INDEX idx_bitacora_usuario_id ON bitacora_logs(usuario_id);
CREATE INDEX idx_bitacora_accion ON bitacora_logs(accion);
CREATE INDEX idx_bitacora_fecha_hora ON bitacora_logs(fecha_hora);

-- Fin del script.
