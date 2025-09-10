
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
 * Es crucial que esta función sea robusta y maneje errores de configuración.
 * @returns {Promise<boolean>} `true` si hay al menos un usuario, `false` si no o en caso de error.
 */
export async function hasUsers(): Promise<boolean> {
  // Si el cliente de admin no se pudo inicializar (faltan env vars), no hay usuarios.
  if (!supabaseAdmin) {
    console.warn('Supabase admin client is not configured. Assuming no users exist.');
    return false;
  }
  
  try {
    const { data, error } = await supabaseAdmin.auth.admin.listUsers();
    
    // Si la API key es inválida o hay otro error de Supabase, lo capturamos.
    if (error) {
      console.error('Error checking for users:', error.message);
      // Es más seguro devolver false para no bloquear el setup en caso de un error de configuración.
      return false;
    }
    
    return data.users.length > 0;
  } catch (err: any) {
    console.error('Catastrophic error checking for users:', err.message);
    return false;
  }
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

  // 1. Intentar registrar al nuevo usuario.
  const { data: signupData, error: signupError } = await supabase.auth.signUp({
    email,
    password,
    options: {
      // Opcional: Desactivar el email de confirmación si se configura en el panel de Supabase
      // emailRedirectTo: `${new URL(request.url).origin}/auth/callback`,
    },
  });

  if (signupError) {
    console.error('Supabase signup error:', signupError.message);
    return { error: { message: 'No se pudo crear la cuenta. ' + signupError.message } };
  }

  // 2. Comprobar si el usuario se creó pero no se inició sesión (comportamiento por defecto)
  if (signupData.user && !signupData.session) {
    // 3. Iniciar sesión manualmente para establecer la sesión
    const { data: signinData, error: signinError } = await supabase.auth.signInWithPassword({
      email,
      password,
    });

    if (signinError) {
      console.error('Supabase signin after signup error:', signinError.message);
      return { error: { message: 'Se creó el usuario, pero no se pudo iniciar sesión. Contacte al soporte.' } };
    }
    
    if (!signinData.session) {
        return { error: { message: 'No se pudo iniciar sesión después del registro.' } };
    }

  } else if (!signupData.session) {
      return { error: { message: 'No se pudo obtener una sesión después del registro.' } };
  }
  
  revalidatePath('/'); // Invalida la cache para que la próxima comprobación de `hasUsers` sea correcta.
  redirect('/admin'); // Redirige al panel de admin tras el registro y login exitosos.
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
    // Este error puede ocurrir si el admin todavia no fue creado con las credenciales correctas.
    if(error.message.includes('Invalid login credentials')) {
        return { error: { message: 'El usuario admin no existe o la contraseña es incorrecta. Regístrelo primero.'}};
    }
    return { error: { message: 'Error de autenticación. Verifique la consola del servidor.' } };
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
