#!/usr/bin/env bash
# Crea una cuenta superadmin en la BD de Compose (el registro de la página solo crea lectores).
# Se corre donde está Compose (el servidor); pide los datos y la contraseña, que no se ve en
# pantalla ni queda en el historial:
#   bash InfraBiblioTK/scripts/crear-superadmin.sh
set -euo pipefail
cd "$(dirname "$0")/.."

read -rp "Nombres: " nombres
read -rp "Apellidos: " apellidos
read -rp "Correo: " email
read -rp "Cédula: " cc
read -rp "Celular: " celular
read -rp "Nombre de usuario: " nombreusuario
read -rsp "Contraseña: " contrasena; echo
read -rsp "Repite la contraseña: " repetida; echo

if [ "$contrasena" != "$repetida" ]; then echo "Las contraseñas no coinciden" >&2; exit 1; fi
if [ "${#contrasena}" -lt 8 ]; then echo "La contraseña debe tener al menos 8 caracteres" >&2; exit 1; fi

# Corre dentro del contenedor de login: ya trae bcrypt, mysql2 y las variables DB_* de Compose.
# Los datos llegan por la entrada estándar, una línea cada uno (nunca como argumentos visibles)
js=$(cat <<'JS'
const bcrypt = require("bcrypt");
const mysql = require("mysql2/promise");

let entrada = "";
process.stdin.on("data", (parte) => (entrada += parte));
process.stdin.on("end", async () => {
  const [nombres, apellidos, email, cc, celular, nombreusuario, contrasena] = entrada.split("\n");
  const pool = mysql.createPool({
    host: process.env.DB_HOST,
    port: Number(process.env.DB_PORT),
    user: process.env.DB_USER,
    password: process.env.DB_PASSWORD,
    database: process.env.DB_NAME,
  });

  try {
    // Misma comprobación de unicidad que RegistroBiblioTK (la BD no tiene índices UNIQUE)
    const [existentes] = await pool.query(
      "SELECT id FROM usuarios WHERE email = ? OR cc = ? OR nombreusuario = ?",
      [email, cc, nombreusuario],
    );
    if (existentes.length) {
      console.error("Ya existe una cuenta con ese correo, cédula o nombre de usuario");
      process.exitCode = 1;
      return;
    }

    const hash = await bcrypt.hash(contrasena, 10);
    await pool.query(
      `INSERT INTO usuarios
        (nombres, apellidos, email, cc, password, rol, fecharegistro, activo, celular, nombreusuario)
        VALUES (?, ?, ?, ?, ?, 'superadmin', NOW(), 1, ?, ?)`,
      [nombres, apellidos, email, cc, hash, celular, nombreusuario],
    );
    console.log(`Cuenta superadmin creada: ${email}`);
  } finally {
    await pool.end();
  }
});
JS
)

printf '%s\n' "$nombres" "$apellidos" "$email" "$cc" "$celular" "$nombreusuario" "$contrasena" |
  docker compose exec -T login node -e "$js"
