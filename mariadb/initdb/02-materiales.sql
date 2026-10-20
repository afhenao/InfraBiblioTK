-- Catálogo de ejemplo para que la demostración tenga libros que prestar.
-- No se crean cuentas: los lectores se registran desde la landing y, para probar las apps del
-- bibliotecario o del superadministrador, se cambia el rol de una cuenta (ver InfraBiblioTK/CLAUDE.md).

INSERT INTO `materiales` (`titulo`, `autor`, `tipo_material`, `editorial`, `anio_publicacion`, `disponible`, `fecharegistro`) VALUES
  ('Cien años de soledad', 'Gabriel García Márquez', 'NOVELA', 'Sudamericana', 1967, 1, NOW()),
  ('El amor en los tiempos del cólera', 'Gabriel García Márquez', 'NOVELA', 'Oveja Negra', 1985, 1, NOW()),
  ('María', 'Jorge Isaacs', 'NOVELA', 'Imprenta de Gaitán', 1867, 1, NOW()),
  ('Pedro Páramo', 'Juan Rulfo', 'NOVELA', 'Fondo de Cultura Económica', 1955, 1, NOW()),
  ('Rayuela', 'Julio Cortázar', 'NOVELA', 'Sudamericana', 1963, 1, NOW()),
  ('Ficciones', 'Jorge Luis Borges', 'LIBRO', 'Sur', 1944, 1, NOW()),
  ('Don Quijote de la Mancha', 'Miguel de Cervantes', 'LIBRO', 'Juan de la Cuesta', 1605, 1, NOW()),
  ('Revista Credencial Historia', 'Varios autores', 'REVISTA', 'Credencial', 2020, 1, NOW());
