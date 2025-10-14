
'use server';

import { redirect } from 'next/navigation';
import { revalidatePath } from 'next/cache';
import { createClient } from '@/lib/supabase/server';
import { supabaseAdmin } from '@/lib/supabase/admin';
import type { Client, CartItem } from '@/types';

export interface AuthState {
  error: {
    message: string;
  } | null;
}

export async function hasUsers(): Promise<boolean> {
  if (!supabaseAdmin) {
    console.warn('Supabase admin client not configured. Assuming users exist for security.');
    return true;
  }
  
  try {
    const { data: { users }, error } = await supabaseAdmin.auth.admin.listUsers();
    
    if (error) {
      console.error('Error checking for users:', error.message);
       if (error.message.includes('fetch failed')) {
        console.warn('Fetch failed, possibly due to missing Supabase ENV VARS. Assuming users exist for security.');
        return true;
      }
      return false;
    }
    
    return users.length > 0;
  } catch (err: any) {
    console.error('Catastrophic error checking for users:', err.message);
    // As a security measure, assume users exist if the check fails catastrophically.
    return true;
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
   if (password.length < 6) {
    return { error: { message: 'La contraseña debe tener al menos 6 caracteres.' } };
  }


  const { data, error } = await supabase.auth.signUp({
    email,
    password,
  });

  if (error) {
    console.error('Supabase signup error:', error.message);
    if (error.message.includes('User already registered')) {
        return { error: { message: 'Este correo electrónico ya está registrado.' } };
    }
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
  const supabase = createClient();
  const email = formData.get('email') as string;
  const password = formData.get('password') as string;

  if (!email || !password) {
      return { error: { message: 'El email y la contraseña son requeridos.'}};
  }

  const { error } = await supabase.auth.signInWithPassword({
    email,
    password, 
  });

  if (error) {
    console.error('Supabase login error:', error.message);
    if(error.message.includes('Invalid login credentials')) {
        return { error: { message: 'Credenciales de acceso inválidas.'}};
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

    // 1. Get Agreement, Price List, and Products
    const { data: agreement, error: agreementError } = await supabase
        .from('agreements')
        .select(`
            *,
            agreement_promotions(
                promotions(*)
            ),
            price_lists(
                id,
                name,
                prices_include_vat,
                price_list_items(
                    price,
                    volume_price,
                    products(*)
                )
            )
        `)
        .eq('id', agreementId)
        .single();
        
    if (agreementError || !agreement) {
        console.error("getOrderPageData (agreement) error:", agreementError?.message);
        return { data: null, error: { message: "El convenio no es válido o ha expirado." } };
    }
    if (!agreement.price_lists) {
      return { data: null, error: { message: "Este convenio no tiene una lista de precios asignada." } };
    }

    // 2. Get the client assigned to this agreement
    const { data: client, error: clientError } = await supabase
        .from('clients')
        .select('id, contact_name')
        .eq('agreement_id', agreementId)
        .eq('status', 'active')
        .maybeSingle();

    if (clientError || !client) {
         console.error("getOrderPageData (client) error:", clientError?.message);
        return { data: null, error: { message: "Este convenio no está asignado a ningún cliente activo." } };
    }

    const products = agreement.price_lists.price_list_items.map(pli => ({
        ...pli.products!,
        price: pli.price,
        volume_price: pli.volume_price,
    })).sort((a, b) => a.name.localeCompare(b.name));
    
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
            client,
            productsByCategory
        }, 
        error: null 
    };
}


// --- Onboarding Actions ---
export async function getOnboardingClient(token: string): Promise<{ data: Client | null, error: any }> {
    const supabase = createClient();
    const { data, error } = await supabase
        .from('clients')
        .select('*')
        .eq('onboarding_token', token)
        .single();

    if (error) {
        console.error("getOnboardingClient error:", error.message);
        return { data: null, error };
    }
    return { data, error: null };
}

export async function submitOnboardingForm(payload: Omit<Client, 'id' | 'created_at' | 'status' | 'agreement_id'>) {
    const supabase = createClient();
    
    const { onboarding_token, ...clientData } = payload;

    const { data: existingClient, error: fetchError } = await supabase
        .from('clients')
        .select('agreement_id, status')
        .eq('onboarding_token', onboarding_token)
        .single();
    
    if (fetchError || !existingClient) {
        return { error: { message: 'Enlace de alta inválido.' } };
    }

    // Determine the new status after form submission
    let newStatus: Client['status'] = existingClient.status as Client['status'];
    if (existingClient.status === 'pending_onboarding') {
        newStatus = existingClient.agreement_id ? 'active' : 'pending_agreement';
    }
    
    const { error } = await supabase
        .from('clients')
        .update({ 
            ...clientData, 
            status: newStatus
        })
        .eq('onboarding_token', onboarding_token);

    if (error) {
        console.error("submitOnboardingForm error:", error.message);
        if (error.code === '23505') { // Unique constraint violation
             if (error.message.includes('cuit')) {
                return { error: { message: 'El CUIT ingresado ya está registrado en nuestro sistema.' }};
            }
            if (error.message.includes('email')) {
                return { error: { message: 'El email ingresado ya está registrado en nuestro sistema.' }};
            }
        }
        return { error };
    }

    revalidatePath('/admin/clients');
    return { error: null };
}

// --- Order Submission ---
export async function submitOrder(payload: {
    cart: CartItem[];
    total: number;
    agreementId: string;
    clientId: string;
    clientName: string;
}) {
    const supabase = createClient();

    // 1. Create the order
    const { data: order, error: orderError } = await supabase
        .from('orders')
        .insert({
            client_id: payload.clientId,
            agreement_id: payload.agreementId,
            total_amount: payload.total,
            status: 'pending',
            client_name_cache: payload.clientName
        })
        .select()
        .single();

    if (orderError || !order) {
        console.error("submitOrder (order) error:", orderError?.message);
        return { error: { message: "No se pudo registrar el pedido en la base de datos." } };
    }

    // 2. Create the order items
    const orderItems = payload.cart.map(item => ({
        order_id: order.id,
        product_id: item.product.id,
        quantity: item.quantity,
        price_per_unit: item.product.price,
    }));

    const { error: itemsError } = await supabase.from('order_items').insert(orderItems);

    if (itemsError) {
        console.error("submitOrder (items) error:", itemsError?.message);
        // We should probably delete the order we just created for consistency
        await supabase.from('orders').delete().eq('id', order.id);
        return { error: { message: "No se pudieron guardar los productos del pedido." } };
    }

    // 3. Revalidate paths to update admin dashboard
    revalidatePath('/admin');

    return { data: { orderId: order.id }, error: null };
}
