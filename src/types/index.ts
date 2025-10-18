// These types are manually created to match the Supabase schema.
// For a more robust solution, you can use `supabase gen types typescript`.
import type { analyzeClientFlow } from "@/ai/flows/analyze-client-flow";

export type Product = {
  id: string;
  name: string;
  description: string | null;
  category: string | null;
  image_url: string | null;
  created_at: string;
};

// A Product with an agreement-specific price.
// Used on the order page to ensure the correct price is used.
export type ProductWithPrice = Product & {
  price: number;
  volume_price?: number | null;
};

export type CartItem = {
  product: ProductWithPrice;
  quantity: number;
};

export type Promotion = {
  id: string;
  name: string;
  description: string | null;
  rules: any; // JSON object
  created_at: string;
};

export type SalesCondition = {
  id: string;
  name: string;
  description: string | null;
  rules: any; // JSON object
  created_at: string;
};

export type PriceList = {
    id: string;
    name: string;
    prices_include_vat: boolean;
    created_at: string;
}

export type PriceListItem = {
    price_list_id: string;
    product_id: string;
    price: number;
    volume_price: number | null;
    products: Product; // Joined data
}

export type DetailedPriceList = PriceList & {
    price_list_items: PriceListItem[];
}

// Represents a promotion specifically assigned to an agreement.
export type AgreementPromotion = {
  agreement_id: string;
  promotion_id: string;
  promotions: Promotion; // Joined data from the promotions table
}

export type AgreementSalesCondition = {
  agreement_id: string;
  sales_condition_id: string;
  sales_conditions: SalesCondition; // Joined data from the sales_conditions table
}

export type Agreement = {
  id: string;
  agreement_name: string;
  client_type: "barberia" | "distribuidor" | "especial";
  created_at: string;
  price_list_id: string | null;
};

// Type for the `agreements_with_counts` view
export type AgreementWithCount = Agreement & {
  promotion_count: number;
  sales_condition_count: number;
  price_lists: { name: string } | null
}


export type DetailedAgreement = Agreement & {
  agreement_promotions: AgreementPromotion[]; // Joined data
  agreement_sales_conditions: AgreementSalesCondition[]; // Joined data
  price_lists: { id: string, name: string, prices_include_vat: boolean } | null; // Joined data
  clients: { id: string, contact_name: string | null }[]; // Joined data
}

export type Client = {
    id: string;
    cuit: string | null;
    contact_name: string | null;
    contact_dni: string | null;
    address: string | null;
    delivery_window: string | null;
    email: string | null;
    instagram: string | null;
    status: 'pending_onboarding' | 'pending_agreement' | 'active' | 'archived';
    onboarding_token: string | null;
    agreement_id: string | null;
    created_at: string;
    fiscal_status: string | null;
    latitude: number | null;
    longitude: number | null;
    agreements?: Agreement | null; // Joined data
}

export type Order = {
    id: string;
    client_id: string;
    agreement_id: string;
    created_at: string;
    total_amount: number;
    status: 'pending' | 'completed';
    client_name_cache: string;
    notes?: string | null;
}

export type OrderWithItems = Order & {
    order_items: {
        quantity: number;
        price_per_unit: number;
        products: {
            name: string;
            category: string | null;
        } | null;
    }[];
}

export type DashboardStats = {
    total_revenue: number;
    month_revenue: number;
    active_clients: number;
    overdue_orders_count: number;
    total_clients: number;
    total_pricelists: number;
    total_promotions: number;
    total_sales_conditions: number;
}

export type ClientStats = {
    total_spent: number;
    average_order_value: number;
    total_orders: number;
}

export type AppSettings = {
    whatsapp_number: string;
    vat_percentage: number;
}

// --- AI Flow Types ---
export type AnalyzeClientOutput = {
    summary: string;
    observations: string[];
    opportunities: string[];
    risks: string[];
};
