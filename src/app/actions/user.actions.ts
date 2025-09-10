
'use server';

import { redirect } from 'next/navigation';
import { revalidatePath } from 'next/cache';
import { createClient } from '@/lib/supabase/server';
import { supabaseAdmin } from '@/lib/supabase/admin';

// --- Tipos de Estado para los Formularios ---

export interface AuthState {
  error: {
    message: string;
  } | null;
}

// --- Lógica de Autenticación ---

/**
 * Comprueba si existe algún usuario en la base de datos.
 * Utiliza el cliente de servicio para tener los permisos necesarios.
 * Es crucial que esta función sea robusta.
 * @returns {Promise<boolean>} `true` si hay al menos un usuario, `false` si no o en caso de error.
 */
export async function hasUsers(): Promise<boolean> {
  // Si las variables de entorno cruciales no están, no podemos conectar a Supabase.
  // En este caso, devolvemos `false` para permitir el acceso a la página de registro
  // donde se podrían mostrar instrucciones para configurar el .env.
  if (!process.env.NEXT_PUBLIC_SUPABASE_URL || !process.env.SUPABASE_SERVICE_ROLE_KEY) {
    console.error('Supabase URL or Service Role Key are not configured.');
    return false;
  }
  
  const { data, error } = await supabaseAdmin.auth.admin.listUsers();
  
  if (error) {
    console.error('Error checking for users:', error.message);
    // Si hay un error al consultar (ej. la base de datos no está disponible),
    // es más seguro devolver `false` para no bloquear el proceso de setup.
    return false;
  }
  return data.users.length > 0;
}

/**
 * Acción de registro para el primer super administrador.
 * Falla si ya existe un usuario en el sistema.
 */
export async function signupSuperAdmin(
  prevState: AuthState,
  formData: FormData
): Promise<AuthState> {
  // Medida de seguridad: volver a comprobar si ya hay usuarios antes de intentar crear uno.
  if (await hasUsers()) {
    return { error: { message: 'El registro ya no está disponible. Ya existe un administrador.' } };
  }

  const supabase = createClient();
  const email = formData.get('email') as string;
  const password = formData.get('password') as string;

  if (!email || !password) {
    return { error: { message: 'El email y la contraseña son requeridos.' } };
  }
  // Se requiere que la contraseña coincida con la del admin para el login por PIN.
  if (password !== 'admin1234') {
    return { error: { message: 'La contraseña debe ser "admin1234".' } };
  }
  // Se requiere que el email sea el del admin para el login por PIN.
  if (email !== 'admin@blonde.com') {
    return { error: { message: 'El email debe ser "admin@blonde.com".' } };
  }

  const { error } = await supabase.auth.signUp({ email, password });

  if (error) {
    console.error('Supabase signup error:', error.message);
    return { error: { message: 'No se pudo crear la cuenta. Inténtelo de nuevo.' } };
  }

  revalidatePath('/'); // Invalida la cache para que la próxima comprobación de `hasUsers` sea correcta.
  redirect('/login'); // Redirige a la página de login con PIN tras el registro exitoso.
}

/**
 * Acción de inicio de sesión con un PIN estático.
 */
export async function login(
  prevState: AuthState,
  formData: FormData
): Promise<AuthState> {
  const pin = formData.get('pin') as string;

  // 1. Validar el PIN
  if (pin !== '1234') {
    return { error: { message: 'PIN incorrecto.' } };
  }

  // 2. Si el PIN es correcto, intentar iniciar sesión con las credenciales fijas del admin.
  //    Este usuario debe haber sido creado previamente a través del flujo de registro único.
  const supabase = createClient();
  const { error } = await supabase.auth.signInWithPassword({
    email: 'admin@blonde.com',
    password: 'admin1234', 
  });

  if (error) {
    console.error('Supabase admin login error:', error.message);
    // Este error es para el desarrollador, al usuario le decimos que algo falló.
    return { error: { message: 'Error de autenticación. Verifique que el usuario admin esté configurado.' } };
  }
  
  revalidatePath('/admin');
  redirect('/admin');
}


export async function logout() {
  const supabase = createClient();
  await supabase.auth.signOut();
  redirect('/login');
}

// --- Lógica de Datos (sin cambios) ---
export async function getOrderPageData(agreementId: string) {
    const supabase = createClient();

    const { data: agreement, error: agreementError } = await supabase
        .from('agreements')
        .select(`
            *,
            agreement_products(
                price,
                products(*)
            ),
            agreement_promotions(
                promotions(*)
            )
        `)
        .eq('id', agreementId)
        .single();

    if (agreementError || !agreement) {
        console.error("getOrderPageData (agreement) error:", agreementError?.message);
        return { data: null, error: { message: "El convenio no es válido o ha expirado." } };
    }
    
    const validAgreementProducts = agreement.agreement_products.filter(ap => ap.products);

    const products = validAgreementProducts.map(ap => ({
        ...ap.products!,
        price: ap.price,
    }));

    return { 
        data: { 
            agreement: {
                ...agreement,
                agreement_promotions: agreement.agreement_promotions ?? [],
            }, 
            products 
        }, 
        error: null 
    };
}
