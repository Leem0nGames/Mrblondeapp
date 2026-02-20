
'use server';

import { revalidatePath } from 'next/cache';
import { getSupabaseClientWithAuth } from './_helpers';
import type { Order, OrderWithItems } from '@/types';

export async function getOrders(filters?: { status?: string; query?: string }): Promise<{ data: Order[] | null; error: any }> {
    const supabase = await getSupabaseClientWithAuth();
    let query = supabase.from('orders').select('*').order('created_at', { ascending: false });
    
    if (filters?.status && filters.status !== 'all') {
        query = query.eq('status', filters.status);
    }
    if (filters?.query) {
        query = query.ilike('client_name_cache', `%${filters.query}%`);
    }

    const { data, error } = await query;
    return { data, error };
}

export async function getOrderWithDetails(orderId: string): Promise<{ data: OrderWithItems | null; error: any }> {
    let supabase;
    try {
        supabase = await getSupabaseClientWithAuth();
    } catch {
        const { createClient } = await import('@/lib/supabase/server');
        supabase = await createClient();
    }

    const { data, error } = await supabase
        .from('orders')
        .select('*, order_items(quantity, price_per_unit, products(*)), clients(*)')
        .eq('id', orderId)
        .maybeSingle();
    
    return { data, error };
}

export async function updateOrderStatus(orderId: string, status: 'armado' | 'transito' | 'entregado') {
    const supabase = await getSupabaseClientWithAuth();
    const { error } = await supabase.from('orders').update({ status }).eq('id', orderId);
    if (!error) {
        revalidatePath('/admin');
        revalidatePath('/admin/orders');
    }
    return { error };
}

export async function getPublicOrderDetails(orderId: string) {
    const { createClient } = await import('@/lib/supabase/server');
    const supabase = await createClient();
    const { data, error } = await supabase
        .from('orders')
        .select('*, order_items(quantity, products(name))')
        .eq('id', orderId)
        .maybeSingle();
    return { data, error };
}

export async function publicConfirmOrder(orderId: string) {
    const { createClient } = await import('@/lib/supabase/server');
    const supabase = await createClient();
    const { error } = await supabase.from('orders').update({ status: 'entregado' }).eq('id', orderId);
    if (!error) {
        revalidatePath('/admin');
        revalidatePath('/admin/orders');
    }
    return { error };
}
