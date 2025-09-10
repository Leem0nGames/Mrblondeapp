
"use server";

import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";

export async function login(formData: FormData) {
  const pin = formData.get("pin") as string;
  const adminPin = process.env.ADMIN_PIN || '1234';

  if (pin === adminPin) {
    const supabase = createClient();
    // This is a workaround to create a session for a "dummy" admin user.
    // In a real application, you'd have a proper user management system.
    const { error } = await supabase.auth.signInWithPassword({
      email: process.env.ADMIN_EMAIL!,
      password: process.env.ADMIN_PASSWORD!,
    });

    if (error) {
      return { error: { message: "Credenciales de administrador base no configuradas." } };
    }

    revalidatePath("/", "layout");
    
    if (pin === '1234') {
        // We can't redirect to a dedicated "change PIN" page yet,
        // as that page doesn't exist. For now, we'll just log in.
        // This is where you would redirect to a page to force a PIN change.
        // redirect('/admin/change-pin');
    }

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

    // 1. Verify agreementId and get related agreement with its products
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
        return { error: { message: "El convenio no es válido o no existe." } };
    }
    
    const products = agreement.agreement_products.map(ap => ({
        ...ap.products,
        price: ap.price, // Override base_price with the agreement-specific price
    }));

    return { data: { agreement, products }, error: null };
}
