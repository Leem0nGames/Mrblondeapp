

"use server";

import { getSupabaseClientWithAuth } from "./_helpers";
import { revalidatePath } from "next/cache";
import type { AppSettings } from "@/types";

export async function getSettings(): Promise<AppSettings> {
    const supabase = await getSupabaseClientWithAuth();
    const { data, error } = await supabase.from('app_settings').select('key, value');
    
    if (error) {
        console.error("getSettings error:", error.message);
        return { whatsapp_number: "", vat_percentage: 21, logo_url: null };
    }

    const settings = (data || []).reduce((acc, { key, value }) => {
        acc[key] = key === 'vat_percentage' ? Number(value) : value;
        return acc;
    }, {} as any);

    return {
        whatsapp_number: settings.whatsapp_number || "",
        vat_percentage: settings.vat_percentage || 21,
        logo_url: settings.logo_url || null,
    };
}

export async function updateSettings(formData: FormData): Promise<{ error?: string }> {
    const supabase = await getSupabaseClientWithAuth();
    
    const whatsapp_number = formData.get('whatsapp_number') as string;
    const vat_percentage = formData.get('vat_percentage') as string;
    const logoImage = formData.get('logo_image') as File | null;

    const settingsToUpsert = [
        { key: 'whatsapp_number', value: whatsapp_number },
        { key: 'vat_percentage', value: vat_percentage },
    ];

    if (logoImage && logoImage.size > 0) {
        const fileExt = logoImage.name.split('.').pop();
        const fileName = `logo.${fileExt}`;
        const filePath = `public/${fileName}`;

        const { error: uploadError } = await supabase.storage
            .from('app_assets')
            .upload(filePath, logoImage, {
                cacheControl: '3600',
                upsert: true,
            });
        
        if (uploadError) {
            console.error("Logo upload error:", uploadError.message);
            return { error: "No se pudo subir el nuevo logo." };
        }

        const { data: publicUrlData } = supabase.storage.from('app_assets').getPublicUrl(filePath);
        const logoUrl = `${publicUrlData.publicUrl}?t=${new Date().getTime()}`; // Cache-busting
        settingsToUpsert.push({ key: 'logo_url', value: logoUrl });
    }

    const { error } = await supabase.from('app_settings').upsert(settingsToUpsert, { onConflict: 'key' });
    
    if (error) {
        console.error("updateSettings error:", error.message);
        return { error: "No se pudo guardar la configuración." };
    }

    revalidatePath('/admin', 'layout');
    
    return {};
}
