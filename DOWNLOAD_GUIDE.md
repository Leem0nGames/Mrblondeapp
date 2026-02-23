
# 🚀 Guía de Configuración Local: Mr. Blonde

Sigue estos pasos para correr el proyecto en tu propia computadora:

## 1. Requisitos Previos
*   **Node.js**: Versión 18 o superior.
*   **Cuenta de Supabase**: Necesitas un proyecto activo.

## 2. Instalación
1.  Descarga y descomprime el archivo ZIP del proyecto.
2.  Abre una terminal en la carpeta del proyecto.
3.  Instala las dependencias:
    ```bash
    npm install
    ```

## 3. Configuración de Base de Datos (CRÍTICO)
1.  Ve a tu proyecto en **Supabase** -> **SQL Editor**.
2.  Copia el contenido del archivo `src/lib/supabase/schema.sql`.
3.  Pégalo en el editor y haz clic en **RUN**.
    *Esto creará todas las tablas, funciones y los estados logísticos (armado, transito, entregado).*

## 4. Variables de Entorno
Crea un archivo llamado `.env.local` en la raíz del proyecto y completa los valores con tus claves de Supabase (Settings -> API):

```bash
NEXT_PUBLIC_SUPABASE_URL="tu-url-de-supabase"
NEXT_PUBLIC_SUPABASE_ANON_KEY="tu-anon-key"
SUPABASE_SERVICE_ROLE_KEY="tu-service-role-key"
GEMINI_API_KEY="tu-clave-de-google-ai" # Opcional para las funciones de IA
```

## 5. Iniciar la Aplicación
Ejecuta el comando:
```bash
npm run dev
```
Abre [http://localhost:9003](http://localhost:9003) en tu navegador.

---
**Nota sobre el Primer Acceso:**
La primera vez que entres, el sistema te redirigirá a `/signup` para crear la cuenta del **Super Administrador**. Una vez creada, usa esas credenciales en `/login`.
