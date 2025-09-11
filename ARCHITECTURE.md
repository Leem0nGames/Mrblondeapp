# Arquitectura y Mapa del Proyecto: Blonde Orders

Este documento sirve como guía de referencia para la estructura, lógica y flujos de datos de la aplicación "Blonde Orders". Su propósito es mantener la coherencia y la lógica durante el desarrollo.

## 1. Stack Tecnológico

- **Framework**: Next.js (App Router)
- **Lenguaje**: TypeScript
- **Base de Datos y Auth**: Supabase
- **UI**: Tailwind CSS, shadcn/ui, Radix UI
- **Gestión de Estado (Cliente)**: Zustand
- **Validación de Formularios**: React Hook Form, Zod
- **Funcionalidad IA**: Genkit (Google AI)

## 2. Mapa de Directorios Clave

```
/
├── src/
│   ├── ai/                 # Lógica de Inteligencia Artificial (Genkit)
│   │   ├── flows/          # Flujos de Genkit (e.g., sugerencia de promociones)
│   │   └── genkit.ts       # Configuración e inicialización de Genkit
│   │
│   ├── app/                # Rutas y lógica principal (Next.js App Router)
│   │   ├── (admin)/        # Rutas protegidas del panel de administración
│   │   │   ├── admin/
│   │   │   │   ├── agreements/ # Gestión de convenios (crear, editar, asignar)
│   │   │   │   ├── products/   # CRUD de productos
│   │   │   │   └── promotions/ # CRUD de promociones
│   │   │   └── layout.tsx    # Layout principal del panel de admin (navegación)
│   │   │
│   │   ├── (auth)/         # Rutas de autenticación
│   │   │   ├── login/      # Página de login con PIN
│   │   │   └── signup/     # Página de registro del primer admin
│   │   │
│   │   ├── pedido/[id]/    # Página PÚBLICA para que los clientes realicen pedidos
│   │   │
│   │   ├── actions/        # Server Actions (lógica de backend)
│   │   │   ├── admin.actions.ts # Acciones para el panel de admin
│   │   │   └── user.actions.ts  # Acciones de usuario (auth, pedidos)
│   │   │
│   │   ├── globals.css     # Estilos globales y variables de tema (Tailwind)
│   │   └── layout.tsx      # Layout raíz de la aplicación
│   │
│   ├── components/         # Componentes de UI reutilizables
│   │   ├── shared/         # Componentes genéricos (e.g., PageHeader, EmptyState)
│   │   └── ui/             # Componentes de shadcn/ui (Button, Card, etc.)
│   │
│   ├── hooks/              # Hooks de React personalizados
│   │   └── use-cart-store.ts # Lógica del carrito de compras con Zustand
│   │
│   ├── lib/                # Utilidades y configuración
│   │   ├── supabase/       # Clientes de Supabase (client, server, admin, middleware)
│   │   ├── placeholder-images.ts # Lógica para imágenes de placeholder
│   │   └── utils.ts        # Funciones de utilidad (e.g., cn, formatDate)
│   │
│   └── types/              # Definiciones de tipos de TypeScript
│       └── index.ts        # Tipos principales (Product, Agreement, etc.)
│
├── middleware.ts         # Middleware para gestionar el enrutamiento y la autenticación
│
└── INSTRUCCIONES.md      # Guía de configuración con el script SQL de la DB
```

## 3. Flujos Lógicos Principales

### a. Flujo de Primer Uso (Registro de Administrador)

1.  **Verificación Inicial**: El `middleware.ts` intercepta la primera visita. Llama a la `Server Action` `hasUsers()` de `user.actions.ts`.
2.  **`hasUsers()`**: Esta función usa el cliente de Supabase con `SERVICE_ROLE_KEY` (`supabaseAdmin`) para comprobar si existe algún usuario en la tabla `auth.users`. Es la única función que requiere estos privilegios.
3.  **Redirección**:
    -   Si `hasUsers()` devuelve `false`, el middleware redirige **forzosamente** a `/signup`. Cualquier otro intento de acceso es bloqueado.
    -   Si `hasUsers()` devuelve `true`, el middleware bloquea el acceso a `/signup` y procede con el flujo de autenticación normal.
4.  **Registro**: El formulario en `/signup` llama a la `Server Action` `signupSuperAdmin`. Esta acción crea el usuario con credenciales predefinidas (`admin@blonde.com`).
5.  **Redirección Post-Registro**: Tras el éxito, redirige a `/login` para que el administrador inicie sesión por primera vez con el PIN.

### b. Flujo de Autenticación de Administrador

1.  **Acceso a `/login`**: El usuario (administrador) accede a la página de login e introduce el PIN estático (`1234`).
2.  **Acción de Login**: El formulario llama a la `Server Action` `login()`.
3.  **Validación y Sesión**: `login()` verifica el PIN. Si es correcto, usa `signInWithPassword` de Supabase con las credenciales fijas del administrador para establecer una sesión.
4.  **Redirección a Admin**: Con una sesión válida, el `middleware` redirige al usuario a `/admin/agreements`. Las rutas dentro de `/admin` están protegidas y requieren una sesión activa.

### c. Flujo de Creación y Envío de Pedido

1.  **Admin Genera Link**: En el panel de admin (`/admin/agreements`), el admin copia el enlace único para un convenio. Este enlace contiene el ID del convenio (e.g., `/pedido/uuid-del-convenio`).
2.  **Cliente Accede al Link**: El cliente abre el enlace. La página `/pedido/[id]/page.tsx` se renderiza en el servidor.
3.  **Obtención de Datos**: La página llama a la `Server Action` `getOrderPageData(id)`. Esta acción consulta la base de datos para obtener los detalles del convenio, los productos asignados con sus precios específicos y las promociones aplicables.
4.  **Renderizado de la Página**: La página se muestra al cliente con los productos agrupados por categoría en `Accordions`.
5.  **Interacción del Cliente**:
    -   El cliente añade o quita productos. El estado del carrito se gestiona en el cliente con `useCartStore` (Zustand) para una experiencia instantánea.
    -   Con cada cambio en el carrito, el componente `IntelligentSuggestions` llama de forma asíncrona al flujo de Genkit `suggestPromotions`.
    -   La IA analiza el carrito y las promociones disponibles y devuelve sugerencias personalizadas, que se muestran en tiempo real.
6.  **Finalización del Pedido**:
    -   El cliente abre el `CartWidget` y procede a la `OrderSummarySheet`.
    -   El resumen muestra el detalle del pedido y las bonificaciones calculadas.
    -   Al hacer clic en "Enviar", la función `formatWhatsAppMessage` construye un texto pre-formateado y abre la URL de WhatsApp para enviar el pedido.
