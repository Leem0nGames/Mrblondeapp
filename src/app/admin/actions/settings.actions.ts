"use server";

import { getSupabaseClientWithAuth } from "./_helpers";
import { revalidatePath } from "next/cache";
import type { AppSettings } from "@/types";

export async function getSettings(): Promise<AppSettings> {
    const supabase = await getSupabaseClientWithAuth();
    const { data, error } = await supabase.from('app_settings').select('key, value');
    
    if (error) {
        console.error("getSettings error:", error.message);
        return { whatsapp_number: "", vat_percentage: 21 };
    }

    const settings = (data || []).reduce((acc, { key, value }) => {
        acc[key] = key === 'vat_percentage' ? Number(value) : value;
        return acc;
    }, {} as any);

    return {
        whatsapp_number: settings.whatsapp_number || "",
        vat_percentage: settings.vat_percentage || 21,
    };
}


export async function updateSettings(payload: AppSettings): Promise<{ error?: string }> {
    const supabase = await getSupabaseClientWithAuth();
    
    const settingsToUpsert = Object.entries(payload).map(([key, value]) => ({
        key,
        value: String(value)
    }));

    const { error } = await supabase.from('app_settings').upsert(settingsToUpsert, { onConflict: 'key' });
    
    if (error) {
        console.error("updateSettings error:", error.message);
        return { error: "No se pudo guardar la configuración." };
    }

    revalidatePath('/admin/settings');
    revalidatePath('/pedido', 'layout'); // Revalidate all order pages
    
    return {};
}
