-- Tablas base de BiblioTK (las mismas de la BD local). Se ejecuta solo la primera vez que arranca
-- el contenedor de MariaDB, con el volumen vacío.
-- Las demás las crean los servicios al arrancar: reportes (Préstamos) y sesiones (InicioSesion).

CREATE TABLE IF NOT EXISTS `usuarios` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `nombres` varchar(50) DEFAULT NULL,
  `apellidos` varchar(50) DEFAULT NULL,
  `email` varchar(100) DEFAULT NULL,
  `cc` varchar(15) DEFAULT NULL,
  `password` varchar(255) NOT NULL,
  `rol` enum('usuario','admin','superadmin') NOT NULL DEFAULT 'usuario',
  `fecharegistro` datetime DEFAULT NULL,
  `activo` tinyint(1) NOT NULL DEFAULT 1,
  `celular` varchar(15) DEFAULT NULL,
  `nombreusuario` varchar(30) DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;

CREATE TABLE IF NOT EXISTS `materiales` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `titulo` varchar(150) DEFAULT NULL,
  `autor` varchar(100) DEFAULT NULL,
  `tipo_material` enum('LIBRO','REVISTA','NOVELA','ARTICULOS') NOT NULL DEFAULT 'LIBRO',
  `editorial` varchar(100) DEFAULT NULL,
  `anio_publicacion` smallint(5) unsigned DEFAULT NULL,
  `isbn` varchar(20) DEFAULT NULL,
  `imagen_local` varchar(255) DEFAULT NULL,
  `imagen_url` varchar(500) DEFAULT NULL,
  `disponible` tinyint(1) NOT NULL DEFAULT 1,
  `fecharegistro` datetime DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;

CREATE TABLE IF NOT EXISTS `prestamos` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `usuario_id` int(10) unsigned NOT NULL,
  `material_id` int(10) unsigned NOT NULL,
  `fecha_solicitud` datetime DEFAULT NULL,
  `fecha_respuesta` datetime DEFAULT NULL,
  `fecha_prestamo` datetime DEFAULT NULL,
  `fecha_devolucion_esperada` datetime DEFAULT NULL,
  `fecha_devolucion_real` datetime DEFAULT NULL,
  `fecha_cancelacion` datetime DEFAULT NULL,
  `cancelado_por` varchar(20) DEFAULT NULL,
  `estado` enum('SOLICITADO','ACTIVO','DEVUELTO','VENCIDO','CANCELADO','RECHAZADO') NOT NULL DEFAULT 'ACTIVO',
  `observaciones` varchar(255) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_usuario` (`usuario_id`),
  KEY `idx_material` (`material_id`),
  CONSTRAINT `fk_prestamos_materiales` FOREIGN KEY (`material_id`) REFERENCES `materiales` (`id`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `fk_prestamos_usuarios` FOREIGN KEY (`usuario_id`) REFERENCES `usuarios` (`id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;
