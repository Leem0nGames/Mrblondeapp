// These types are manually created to match the Supabase schema.
// For a more robust solution, you can use `supabase gen types typescript`.

export type Product = {
  id: string;
  name: string;
  description: string | null;
  base_price: number;
  stock: number;
  category: string | null;
  created_at: string;
};

export type ClientPrice = {
  id: string;
  product_id: string;
  client_type: "barberia" | "distribuidor" | "especial";
  price: number;
  created_at: string;
};

export type Promotion = {
  id: string;
  client_type: "barberia" | "distribuidor" | "especial";
  name: string;
  description: string | null;
  threshold: number;
  bonus: number;
  is_global: boolean;
  created_at: string;
};

export type Agreement = {
  id: string;
  name: string;
  client_type: "barberia" | "distribuidor" | "especial";
  price_adjustment: number;
  promo_override: { threshold: number; bonus: number } | null;
  created_at: string;
};

export type AccessToken = {
    id: string;
    agreement_id: string;
    client_name: string;
    token: string;
    expires_at: string;
    created_at: string;
    agreement: Agreement; // Joined data
}

export type OrderLog = {
  id: string;
  agreement_id: string | null;
  order_data: object | null;
  sent_at: string;
};

export type ClientDetails = {
    name: string;
    phone: string;
    address: string;
    city: string;
}
