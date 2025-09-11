
'use server';

import { redirect } from 'next/navigation';
import { revalidatePath } from 'next/cache';
import { createClient } from '@/lib/supabase/server';
import { supabaseAdmin } from '@/lib/supabase/admin';

export interface AuthState {
  error: {
    message: string;
  } | null;
}

export async function hasUsers(): Promise<boolean> {
  if (!supabaseAdmin) {
    console.warn('Supabase admin client is not configured. Assuming no users exist.');
    return false;
  }
  
  try {
    const { data, error } = await supabaseAdmin.auth.admin.listUsers();
    
    if (error) {
      console.error('Error checking for users:', error.message);
      return false;
    }
    
    return data.users.length > 0;
  } catch (err: any) {
    console.error('Catastrophic error checking for users:', err.message);
    return false;
  }
}

export async function signupSuperAdmin(
  prevState: AuthState,
  formData: FormData
): Promise<AuthState> {
  if (await hasUsers()) {
    return { error: { message: 'El registro ya no está disponible. Ya existe un administrador.' } };
  }

  const supabase = createClient();
  const email = formData.get('email') as string;
  const password = formData.get('password') as string;

  if (!email || !password) {
    return { error: { message: 'El email y la contraseña son requeridos.' } };
  }

  const { data, error } = await supabase.auth.signUp({
    email,
    password,
  });

  if (error) {
    console.error('Supabase signup error:', error.message);
    return { error: { message: 'No se pudo crear la cuenta. ' + error.message } };
  }

  if (data.user) {
    revalidatePath('/'); 
    redirect('/login');
  }

  return { error: { message: 'Ocurrió un error inesperado durante el registro.' }};
}

export async function login(
  prevState: AuthState,
  formData: FormData
): Promise<AuthState> {
  const pin = formData.get('pin') as string;

  if (pin !== '1234') {
    return { error: { message: 'PIN incorrecto.' } };
  }

  const supabase = createClient();
  const { error } = await supabase.auth.signInWithPassword({
    email: 'admin@blonde.com',
    password: 'admin1234', 
  });

  if (error) {
    console.error('Supabase admin login error:', error.message);
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

export async function getOrderPageData(agreementId: string) {
    const supabase = createClient();

    const { data: agreement, error: agreementError } = await supabase
        .from('agreements')
        .select(`
            *,
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

    const { data: agreementProducts, error: productsError } = await supabase
        .from('agreement_products')
        .select(`
            price,
            products(*)
        `)
        .eq('agreement_id', agreementId)
        .order('name', { foreignTable: 'products', ascending: true });
    
    if (productsError) {
        console.error("getOrderPageData (products) error:", productsError.message);
        return { data: null, error: { message: "No se pudieron cargar los productos del convenio." } };
    }

    const products = agreementProducts.map(ap => ({
        ...ap.products!,
        price: ap.price,
    }));
    
    const productsByCategory = products.reduce((acc, product) => {
        const category = product.category || 'Sin Categoría';
        if (!acc[category]) {
            acc[category] = [];
        }
        acc[category].push(product);
        return acc;
    }, {} as Record<string, typeof products>);


    return { 
        data: { 
            agreement: {
                ...agreement,
                agreement_promotions: agreement.agreement_promotions ?? [],
            }, 
            products,
            productsByCategory
        }, 
        error: null 
    };
}

    