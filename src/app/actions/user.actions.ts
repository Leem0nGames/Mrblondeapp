
"use server";

import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";

export async function login(formData: FormData) {
  const pin = formData.get("pin") as string;
  // This should be in environment variables
  const adminPin = process.env.ADMIN_PIN || "1234";

  if (pin === adminPin) {
    const supabase = createClient();
    // In a real app, you'd have a proper user management system.
    // For this MVP, we sign in a "dummy" admin user.
    const { error } = await supabase.auth.signInWithPassword({
      email: process.env.ADMIN_EMAIL!,
      password: process.env.ADMIN_PASSWORD!,
    });

    if (error) {
      return { error: { message: "Credenciales de administrador base no configuradas." } };
    }

    revalidatePath("/", "layout");
    redirect("/admin");
  }

  return { error: { message: "PIN incorrecto." } };
}

export async function logout() {
  const supabase = createClient();
  await supabase.auth.signOut();
  redirect("/login");
}

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
    
    // Filter out any products that might be null
    const validAgreementProducts = agreement.agreement_products.filter(ap => ap.products);

    const products = validAgreementProducts.map(ap => ({
        ...ap.products!,
        price: ap.price, // Override base_price with the agreement-specific price
    }));

    return { 
        data: { 
            agreement: {
                ...agreement,
                // Ensure promotions are always an array
                agreement_promotions: agreement.agreement_promotions ?? [],
            }, 
            products 
        }, 
        error: null 
    };
}
