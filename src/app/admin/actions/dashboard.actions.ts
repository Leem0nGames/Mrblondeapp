
"use server";

import { revalidatePath } from "next/cache";
import { getSupabaseClientWithAuth } from "./_helpers";
import type { DashboardStats, Order, Client } from "@/types";

// --- Dashboard Actions ---

export async function getDashboardStats(): Promise<DashboardStats> {
    const supabase = await getSupabaseClientWithAuth();
    
    const { data, error } = await supabase.from("dashboard_stats").select("*").single();

    if (error || !data) {
        console.error("getDashboardStats error:", error?.message);
        return {
            total_revenue: 0,
            month_revenue: 0,
            active_clients: 0
        };
    }
    return data;
}

export async function getPendingOrders(): Promise<Order[]> {
    const supabase = await getSupabaseClientWithAuth();
    const { data, error } = await supabase
        .from("orders")
        .select("id, client_id, agreement_id, created_at, total_amount, status, client_name_cache, notes")
        .eq("status", "pending")
        .order("created_at", { ascending: false })
        .limit(5);

    if (error) {
        console.error("getPendingOrders error:", error.message);
        return [];
    }
    return data;
}

export async function getOverdueOrders(): Promise<Order[]> {
    const supabase = await getSupabaseClientWithAuth();
    const { data, error } = await supabase.rpc('get_overdue_orders');

    if (error) {
        console.error("getOverdueOrders error:", error.message);
        return [];
    }
    return data;
}

export async function getClientOrders(clientId: string): Promise<Order[]> {
    const supabase = await getSupabaseClientWithAuth();
    const { data, error } = await supabase
        .from("orders")
        .select("*")
        .eq("client_id", clientId)
        .order("created_at", { ascending: false });

    if (error) {
        console.error("getClientOrders error:", error.message);
        return [];
    }
    return data;
}

export async function completeOrder(orderId: string, orderTotal: number) {
    const supabase = await getSupabaseClientWithAuth();
    
    const { error: orderUpdateError } = await supabase
        .from('orders')
        .update({ status: 'completed' })
        .eq('id', orderId);

    if (orderUpdateError) {
        console.error("completeOrder (order) error:", orderUpdateError.message);
        return { error: orderUpdateError };
    }

    const { error: rpcError } = await supabase.rpc('increment_total_revenue', {
      amount_to_add: orderTotal
    });

    if (rpcError) {
        console.error("completeOrder (rpc) error:", rpcError.message);
        return { error: rpcError };
    }

    revalidatePath('/admin');
    return { error: null };
}
