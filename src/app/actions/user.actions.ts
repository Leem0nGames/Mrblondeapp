

'use server';

import { redirect } from 'next/navigation';
import { revalidatePath } from 'next/cache';
import { createClient as createServerClient } from '@/lib/supabase/server';
import { supabaseAdmin } from '@/lib/supabase/admin';
import type { Client, CartItem, AuthState } from '@/types';

export async function hasUsers(): Promise<boolean> {
  // If the admin client isn't configured (e.g., missing ENV VARS in Vercel),
  // securely assume users exist to prevent the signup page from showing.
  if (!supabaseAdmin) {
    console.warn('Supabase admin client not configured. Assuming users exist for security.');
    return true;
  }
  
  try {
    const { data: { users }, error } = await supabaseAdmin.auth.admin.listUsers();
    
    if (error) {
      // This handles cases where Vercel/Netlify can't reach Supabase during build.
      // We'll log the error but assume users exist to be safe.
      console.error('Error checking for users:', error.message);
      return true;
    }
    
    return users.length > 0;
  } catch (err: any) {
    console.error('Catastrophic error checking for users:', err.message);
    // As a final security measure, assume users exist if the check fails.
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

  const supabase = await createServerClient();
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
  const supabase = await createServerClient();
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
  const supabase = await createServerClient();
  await supabase.auth.signOut();
  redirect('/login');
}

export async function getOrderPageData(agreementId: string) {
    const supabase = await createServerClient(); // Use server client for anon access

    const [agreementResult, settingsResult] = await Promise.all([
        supabase
            .from('agreements')
            .select(`
                *,
                agreement_promotions(
                    promotions(*)
                ),
                price_lists(id, name, prices_include_vat)
            `)
            .eq('id', agreementId)
            .maybeSingle(),
        supabase.from('app_settings').select('key, value')
    ]);

    const { data: agreement, error: agreementError } = agreementResult;
        
    if (agreementError || !agreement) {
        console.error("getOrderPageData (agreement) error:", agreementError?.message);
        return { data: null, error: { message: "El convenio no es válido o ha expirado." } };
    }

    if (!agreement.price_lists) {
        return { data: null, error: { message: "Este convenio no tiene una lista de precios asignada." } };
    }

    const { data: priceListItems, error: itemsError } = await supabase
        .from('price_list_items')
        .select(`
            price,
            volume_price,
            products(*)
        `)
        .eq('price_list_id', agreement.price_lists.id)
        .not('products', 'is', null);

    if (itemsError) {
        console.error("getOrderPageData (items) error:", itemsError.message);
        return { data: null, error: { message: "No se pudieron cargar los productos para este convenio." } };
    }

    const { data: client, error: clientError } = await supabase
        .from('clients')
        .select('id, contact_name')
        .eq('agreement_id', agreementId)
        .eq('status', 'active')
        .maybeSingle();

    if (clientError) {
         console.error("getOrderPageData (client) error:", clientError.message);
    }
    const defaultClient = { id: 'generic', contact_name: 'Cliente' };

    const { data: settingsData, error: settingsError } = settingsResult;
    if (settingsError) {
        console.error("getOrderPageData (settings) error:", settingsError.message);
    }

    const settings = (settingsData || []).reduce((acc, { key, value }) => {
        acc[key] = key === 'vat_percentage' ? Number(value) : value;
        return acc;
    }, {} as any);
    
    const vatPercentage = settings.vat_percentage || 21;
    const logoUrl = settings.logo_url || null;

    const products = priceListItems.map(pli => ({
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
            client: client || defaultClient,
            productsByCategory,
            vatPercentage,
            logoUrl,
        }, 
        error: null 
    };
}


// --- Onboarding Actions ---
export async function getOnboardingClient(token: string): Promise<{ data: Client | null, error: any }> {
    const supabase = await createServerClient();
    const { data, error } = await supabase
        .from('clients')
        .select('*')
        .eq('onboarding_token', token)
        .maybeSingle();

    if (error) {
        console.error("getOnboardingClient error:", error.message);
        return { data: null, error: { message: error.message } };
    }
    return { data, error: null };
}

type SubmitOnboardingPayload = Omit<Client, 'id' | 'created_at' | 'status' | 'agreement_id' | 'agreements'> & {
  street_address: string;
  street_number: string;
  locality: string;
  province: string;
  delivery_days: string[];
  delivery_time_from: string;
  delivery_time_to: string;
};

export async function submitOnboardingForm(payload: SubmitOnboardingPayload) {
    const supabase = await createServerClient();
    
    const { 
        onboarding_token, 
        delivery_days,
        delivery_time_from,
        delivery_time_to,
        street_address,
        street_number,
        locality,
        province,
        ...clientData 
    } = payload;

    const { data: existingClient, error: fetchError } = await supabase
        .from('clients')
        .select('agreement_id, status')
        .eq('onboarding_token', onboarding_token)
        .single();
    
    if (fetchError || !existingClient) {
        return { error: { message: 'Enlace de alta inválido.' } };
    }

    let newStatus: Client['status'];
    if (existingClient.agreement_id) {
        newStatus = 'active';
    } else {
        newStatus = 'pending_agreement';
    }
    
    const address = `${street_address} ${street_number}, ${locality}, ${province}`;
    const delivery_window = `${delivery_days.join(', ')} de ${delivery_time_from} a ${delivery_time_to}hs`;

    const { error } = await supabase
        .from('clients')
        .update({ 
            ...clientData,
            address,
            delivery_window, 
            status: newStatus,
            contact_name: payload.contact_name
        })
        .eq('onboarding_token', onboarding_token);

    if (error) {
        console.error("submitOnboardingForm error:", error.message);
        if (error.code === '23505') { 
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
    revalidatePath(`/onboarding/${onboarding_token}`);
    return { error: null };
}

// --- Order Submission ---
export async function submitOrder(payload: {
    cart: CartItem[];
    total: number;
    agreementId: string;
    clientId: string;
    clientName: string;
    notes?: string;
}) {
    const supabase = await createServerClient();

    // 1. Create the order
    const { data: order, error: orderError } = await supabase
        .from('orders')
        .insert({
            client_id: payload.clientId,
            agreement_id: payload.agreementId,
            total_amount: payload.total,
            status: 'pending',
            client_name_cache: payload.clientName,
            notes: payload.notes || null,
        })
        .select()
        .single();

    if (orderError || !order) {
        console.error("submitOrder (order) error:", orderError?.message);
        return { error: { message: "No se pudo registrar el pedido en la base de datos." } };
    }

    const totalItemsInCart = payload.cart.reduce((acc, item) => acc + item.quantity, 0);
    const isVolumeActive = totalItemsInCart >= 150;

    // 2. Create the order items
    const orderItems = payload.cart.map(item => {
      const useVolumePrice = isVolumeActive && item.product.volume_price && item.product.volume_price < item.product.price;
      const pricePerUnit = useVolumePrice ? item.product.volume_price! : item.product.price;
      
      return {
        order_id: order.id,
        product_id: item.product.id,
        quantity: item.quantity,
        price_per_unit: pricePerUnit,
      };
    });

    const { error: itemsError } = await supabase.from('order_items').insert(orderItems);

    if (itemsError) {
        console.error("submitOrder (items) error:", itemsError.message);
        // We should probably delete the order we just created for consistency
        await supabase.from('orders').delete().eq('id', order.id);
        return { error: { message: "No se pudieron guardar los productos del pedido." } };
    }

    // 3. Revalidate paths to update admin dashboard
    revalidatePath('/admin');

    return { data: { orderId: order.id }, error: null };
}
