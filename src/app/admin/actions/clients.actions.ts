
'use server';

import { revalidatePath } from 'next/cache';
import { getSupabaseClientWithAuth, upsertEntity } from './_helpers';
import type {
  Client,
  ClientStats,
  OrderWithItems,
  AnalyzeClientOutput,
} from '@/types';
import { analyzeClientFlow } from '@/ai/flows/analyze-client-flow';
import { supabaseAdmin } from '@/lib/supabase/admin';
import { getSupabaseErrorMessage } from '@/lib/supabase-error-messages';

// --- Client Actions ---
export async function getClients(
  query?: string
): Promise<{ data: Client[] | null; error: any }> {
  const supabase = await getSupabaseClientWithAuth();

  let queryBuilder = supabase
    .from('clients')
    .select(
      `
            *,
            agreements ( agreement_name )
        `
    )
    .in('status', ['active', 'pending_agreement']) // Removed 'pending_onboarding'
    .order('created_at', { ascending: false });

  if (query) {
    const cleanedQuery = `%${query.replace(/\s/g, '%')}%`;
    queryBuilder = queryBuilder.or(
      `contact_name.ilike.${cleanedQuery},cuit.ilike.${cleanedQuery},address.ilike.${cleanedQuery}`
    );
  }

  const { data, error } = await queryBuilder;

  if (error) {
    console.error('getClients error:', error.message);
    return { data: null, error };
  }

  return { data, error: null };
}

export async function getClientById(
  id: string
): Promise<{ data: Client | null; error: any }> {
  const supabase = await getSupabaseClientWithAuth();

  const { data: client, error } = await supabase
    .from('clients')
    .select(
      `
            *,
            agreements ( * )
        `
    )
    .eq('id', id)
    .single();

  if (error) {
    console.error('getClientById error:', error.message);
    return { data: null, error };
  }

  return { data: client, error: null };
}

export async function upsertClient(payload: Partial<Client> & { id?: string }) {
  const { id, ...clientData } = payload;
  let status = clientData.status;

  // Determine status based on agreement_id if not explicitly provided
  if (!status || status === 'pending_onboarding') {
      status = payload.agreement_id ? 'active' : 'pending_agreement';
  }

  const finalPayload = { ...clientData, status, id };
  
  const result = await upsertEntity('clients', finalPayload, [
    '/admin/clients',
    '/admin',
    id ? `/admin/clients/${id}` : ''
  ].filter(Boolean));
  
  if (result.error) {
    return { data: null, error: { message: getSupabaseErrorMessage(result.error) } };
  }

  return { data: result.data, error: null };
}

export async function deleteClient(id: string) {
  const supabase = await getSupabaseClientWithAuth();
  const { error } = await supabase
    .from('clients')
    .update({ status: 'archived' })
    .eq('id', id);

  if (error) {
    console.error('deleteClient (archive) error:', error.message);
    return { error };
  }
  revalidatePath('/admin/clients');
  revalidatePath('/admin');
  return { error: null };
}

export async function assignAgreementToClient(payload: {
  clientId: string;
  agreementId: string | null;
}): Promise<{ error: any }> {
  const supabase = await getSupabaseClientWithAuth();

  const { error } = await supabase
    .from('clients')
    .update({
      agreement_id: payload.agreementId,
      status: payload.agreementId ? 'active' : 'pending_agreement',
    })
    .eq('id', payload.clientId);

  if (error) {
    console.error('assignAgreementToClient error:', error.message);
    return { error };
  }

  revalidatePath('/admin/clients');
  revalidatePath(`/admin/clients/${payload.clientId}`);
  revalidatePath('/admin');
  return { error: null };
}

export async function getClientOrdersWithDetails(
  clientId: string
): Promise<{ data: OrderWithItems[] | null; error: any }> {
  const supabase = await getSupabaseClientWithAuth();
  const { data, error } = await supabase
    .from('orders')
    .select(
      `
            *,
            order_items (
                quantity,
                price_per_unit,
                products ( name, category )
            )
        `
    )
    .eq('client_id', clientId)
    .order('created_at', { ascending: false });

  if (error) {
    console.error('getClientOrdersWithDetails error:', error.message);
    return { data: null, error };
  }
  return { data, error: null };
}

export async function getClientStats(
  clientId: string
): Promise<{ data: ClientStats | null; error: any }> {
  const supabase = await getSupabaseClientWithAuth();

  const { data, error } = await supabase
    .rpc('get_client_stats', { p_client_id: clientId })
    .single();

  if (error) {
    console.error('getClientStats error:', error.message);
    return { data: null, error };
  }

  return { data: data as ClientStats, error: null };
}

export async function analyzeClient(
  clientId: string
): Promise<{ data: AnalyzeClientOutput | null; error: any }> {
  if (!process.env.GEMINI_API_KEY) {
      console.error("GEMINI_API_KEY is not set.");
      return { data: null, error: { message: "La clave API de IA no está configurada en el servidor." } };
  }

  const [clientResult, ordersResult] = await Promise.all([
    getClientById(clientId),
    getClientOrdersWithDetails(clientId),
  ]);

  if (clientResult.error || !clientResult.data) {
    return { data: null, error: { message: 'No se pudo encontrar al cliente.' } };
  }
  if (ordersResult.error) {
    return {
      data: null,
      error: { message: 'No se pudieron obtener los pedidos del cliente.' },
    };
  }

  const client = clientResult.data;
  const orders = ordersResult.data ?? [];

  try {
    const analysis = await analyzeClientFlow({ client, orders });
    return { data: analysis, error: null };
  } catch (e: any) {
    console.error('Error analyzing client:', e.message);
    return {
      data: null,
      error: {
        message: 'La IA no pudo completar el análisis en este momento.',
      },
    };
  }
}

export async function geocodeAddressAndSave(clientId: string, address: string) {
  if (!process.env.GOOGLE_MAPS_API_KEY) {
    console.warn('Google Maps API key is not configured. Skipping geocoding.');
    return { data: null, error: { message: 'API key not configured.' } };
  }
  const url = `https://maps.googleapis.com/maps/api/geocode/json?address=${encodeURIComponent(
    address
  )}&key=${process.env.GOOGLE_MAPS_API_KEY}`;

  try {
    const response = await fetch(url);
    const data = await response.json();

    if (data.status !== 'OK' || !data.results[0]) {
      throw new Error(`Geocoding failed: ${data.status}`);
    }

    const { lat, lng } = data.results[0].geometry.location;

    if (!supabaseAdmin) {
      throw new Error('Admin client not available for updating coordinates.');
    }

    const { error: updateError } = await supabaseAdmin
      .from('clients')
      .update({ latitude: lat as number, longitude: lng as number })
      .eq('id', clientId);

    if (updateError) {
      throw updateError;
    }

    revalidatePath(`/admin/clients/${clientId}`);
    return { data: { latitude: lat, longitude: lng }, error: null };
  } catch (error: any) {
    console.error('Geocoding and saving error:', error.message);
    return { data: null, error: { message: error.message } };
  }
}
