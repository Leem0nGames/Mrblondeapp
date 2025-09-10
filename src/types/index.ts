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

export type Client = {
  id: string;
  name: string;
  phone: string | null;
  address: string | null;
  city: string | null;
  created_at: string;
}

export type Promotion = {
  id: string;
  name: string;
  description: string | null;
  // Simple example: { "type": "buy_x_get_y_free", "buy": 6, "get": 1 }
  // or { "type": "free_shipping", "min_units": 12, "cities": ["CABA"] }
  // This allows for flexible, JSON-based rule definitions.
  rules: any;
  created_at: string;
};

export type Agreement = {
  id: string;
  name: string;
  client_type: "barberia" | "distribuidor" | "especial";
  price_adjustment: number;
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
