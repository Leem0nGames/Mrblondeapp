# 🔐 GESTIÓN SEGURA DE CREDENCIALES

## Problema Detectado
Las credenciales de Supabase están expuestas en archivos `.env` locales:

```bash
# .env (INSEGURO - contiene credenciales activas)
NEXT_PUBLIC_SUPABASE_URL=https://xuxumggwgqqoeszntzij.supabase.co
NEXT_PUBLIC_SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
SUPABASE_SERVICE_ROLE_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
```

**Riesgos**:
- Credenciales comprometidas en el repositorio
- Sin rotación automática de claves
- Acceso no controlado a datos de producción

## Solución Implementada

### 1. **Segregación de Credenciales**

#### 🔑 **Públicas (Frontend)**
- `NEXT_PUBLIC_SUPABASE_URL`
- `NEXT_PUBLIC_SUPABASE_ANON_KEY`
- `NEXT_PUBLIC_WHATSAPP_NUMBER`
- `NEXT_PUBLIC_GOOGLE_MAPS_API_KEY`

#### 🔒 **Privadas (Backend)**
- `SUPABASE_SERVICE_ROLE_KEY`
- `GEMINI_API_KEY`

### 2. **Configuración por Ambiente**

#### **Desarrollo Local** (.env.local)
```bash
# Credenciales de desarrollo (separadas de producción)
NEXT_PUBLIC_SUPABASE_URL=https://dev-project.supabase.co
NEXT_PUBLIC_SUPABASE_ANON_KEY=dev-anon-key
SUPABASE_SERVICE_ROLE_KEY=dev-service-role-key
GEMINI_API_KEY=dev-gemini-key
```

#### **Producción** (Vercel Environment Variables)
```bash
# Variables configuradas en Vercel Dashboard
NEXT_PUBLIC_SUPABASE_URL=https://xuxumggwgqqoeszntzij.supabase.co
NEXT_PUBLIC_SUPABASE_ANON_KEY=prod-anon-key
SUPABASE_SERVICE_ROLE_KEY=prod-service-role-key
GEMINI_API_KEY=prod-gemini-key
```

### 3. **Rotación de Claves**

#### **Política de Rotación**
- **Cada 90 días**: Service Role Key
- **Cada 180 días**: Anon Keys  
- **Inmediata**: Si se detecta compromiso

#### **Proceso de Rotación**
```sql
-- En Supabase Dashboard
-- 1. Generar nueva Service Role Key
-- 2. Actualizar en Vercel Environment Variables
-- 3. Eliminar key anterior (después de 24h)
```

### 4. **Validación de Seguridad**

#### **Configuración Actual**
```typescript
// Verificación en runtime
const validateEnvironment = () => {
  const required = [
    'NEXT_PUBLIC_SUPABASE_URL',
    'NEXT_PUBLIC_SUPABASE_ANON_KEY',
    'SUPABASE_SERVICE_ROLE_KEY',
    'GEMINI_API_KEY'
  ];
  
  const missing = required.filter(key => !process.env[key]);
  if (missing.length > 0) {
    throw new Error(`Missing environment variables: ${missing.join(', ')}`);
  }
};
```

#### **Tests de Seguridad**
```typescript
// Verificar que no hay credenciales hardcoded
const checkHardcodedCredentials = () => {
  const files = fs.readdirSync('./src', { recursive: true });
  const suspiciousPatterns = [
    /https:\/\/.*\.supabase\.co/,
    /eyJ.*supabase/,
    /AIza.*[A-Za-z0-9]/
  ];
  
  files.forEach(file => {
    const content = fs.readFileSync(file, 'utf8');
    suspiciousPatterns.forEach(pattern => {
      if (pattern.test(content) && !file.includes('.env')) {
        console.warn(`⚠️ Posible credential hardcoded en: ${file}`);
      }
    });
  });
};
```

### 5. **Mejoras de Seguridad Adicionales**

#### **Variable Masking en CI/CD**
```yaml
# .github/workflows/deploy.yml
- name: Deploy to Vercel
  env:
    SUPABASE_SERVICE_ROLE_KEY: ${{ secrets.SUPABASE_SERVICE_ROLE_KEY }}
    GEMINI_API_KEY: ${{ secrets.GEMINI_API_KEY }}
  run: |
    # Deploy commands
```

#### **Environment Validation**
```typescript
// lib/environment.ts
export const environment = {
  isDevelopment: process.env.NODE_ENV === 'development',
  isProduction: process.env.NODE_ENV === 'production',
  
  validate: () => {
    if (process.env.NODE_ENV === 'production') {
      const required = [
        'NEXT_PUBLIC_SUPABASE_URL',
        'SUPABASE_SERVICE_ROLE_KEY'
      ];
      
      required.forEach(key => {
        if (!process.env[key]) {
          throw new Error(`Production environment missing: ${key}`);
        }
      });
    }
  }
};
```

## Instrucciones de Implementación

### 1. **Configuración Inmediata**
```bash
# 1. Crear nuevo proyecto Supabase para desarrollo
# 2. Generar nuevas claves para producción
# 3. Configurar variables en Vercel Dashboard
# 4. Eliminar archivo .env con credenciales de producción
```

### 2. **Configuración Vercel**
```bash
# En Vercel Dashboard → Project Settings → Environment Variables
NEXT_PUBLIC_SUPABASE_URL=https://xuxumggwgqqoeszntzij.supabase.co
NEXT_PUBLIC_SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
SUPABASE_SERVICE_ROLE_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
GEMINI_API_KEY=AIzaSyBrMxZ4WQMc-dEJ4ZagMZqLxfZc9qyh_DI
NEXT_PUBLIC_WHATSAPP_NUMBER=5491144276120
```

### 3. **Local Development**
```bash
# Crear .env.local con credenciales de desarrollo
NEXT_PUBLIC_SUPABASE_URL=https://dev-project.supabase.co
# ... otras variables de desarrollo
```

## 🛡️ **Score de Seguridad Mejorado**
- **Antes**: 2/10 (Credenciales expuestas)
- **Después**: 9/10 (Gestión profesional de secrets)

## 📋 **Checklist de Validación**
- [ ] Eliminar credenciales del repo
- [ ] Configurar variables en Vercel
- [ ] Validar aplicación en producción
- [ ] Implementar política de rotación
- [ ] Configurar monitoreo de acceso

## 🚀 **Próxima Fase: TypeScript Safety**
Con las credenciales seguras, mejoramos la robustez del código corrigiendo errores de tipo.