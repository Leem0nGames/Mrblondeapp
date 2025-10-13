-- Este script es para poblar la base de datos con datos de ejemplo.
-- Se puede ejecutar de forma segura después de que el schema.sql haya sido ejecutado.

-- --- SEED DATA ---

-- Insertar productos de ejemplo
INSERT INTO public.products (name, description, base_price, category) VALUES
('Cera Capilar "Efecto Mate"', 'Fijación fuerte con acabado mate natural. Ideal para estilos texturizados y definidos. No deja residuos.', 12500.00, 'Ceras'),
('Polvo Texturizador "Volumen Instantáneo"', 'Aporta volumen y textura desde la raíz con un acabado invisible. Perfecto para cabellos finos.', 15000.00, 'Polvos'),
('Aceite para Barba "Leñador Urbano"', 'Hidrata y suaviza la barba y la piel. Mezcla de aceites de argán y jojoba con aroma amaderado.', 11000.00, 'Aceites'),
('Shampoo Sólido "Menta Refrescante"', 'Limpia profundamente el cabello y el cuero cabelludo. Formato sólido ecológico y duradero.', 9800.00, 'Shampoos'),
('Tónico Capilar "Anti-caída"', 'Fortalece el folículo y estimula el crecimiento. Formulado con biotina y extractos naturales.', 18000.00, 'Tónicos'),
('Gel de Fijación Extrema "Rockstar"', 'Control total y brillo duradero para los peinados más atrevidos. Sin alcohol.', 10500.00, 'Geles'),
('Pomada "Brillo Clásico"', 'Fijación media con alto brillo. Ideal para peinados slick back y looks retro.', 13000.00, 'Pomadas'),
('Crema de Peinar "Hidratación Profunda"', 'Define los rizos y controla el frizz. Enriquecida con manteca de karité.', 11500.00, 'Cremas'),
('Spray "Fijación Flexible"', 'Fija el peinado permitiendo movimiento natural. Ideal para acabados y retoques.', 14000.00, 'Sprays'),
('Mascarilla Capilar "Reparación Intensiva"', 'Tratamiento semanal para cabellos dañados por procesos químicos o calor.', 21000.00, 'Tratamientos');


-- Insertar listas de precios de ejemplo
INSERT INTO public.price_lists (name, prices_include_vat) VALUES
('Precios Minoristas Barbería', true),
('Precios Mayoristas Distribuidor', false);

-- Insertar promociones de ejemplo
INSERT INTO public.promotions (name, description, rules) VALUES
('Promo Barberías 8+2', 'Comprando 8 productos de la misma línea, te llevas 2 de regalo.', '{"buy": 8, "get": 2, "type": "buy_x_get_y_free"}'),
('Envío Gratis CABA (12+)', 'Envío sin cargo a toda CABA en compras superiores a 12 unidades.', '{"locations": ["CABA"], "min_units": 12, "type": "free_shipping"}');

-- Insertar condiciones de venta de ejemplo
INSERT INTO public.sales_conditions (name, description, rules) VALUES
('Pago a 30 Días', 'Condición de pago estándar para clientes mayoristas.', '{"days": 30, "type": "net_days"}'),
('5% Off Contado', 'Descuento por pago al contado o transferencia inmediata.', '{"percentage": 5, "type": "discount"}'),
('3 Cuotas sin Interés', 'Financiación en 3 pagos para compras seleccionadas.', '{"installments": 3, "type": "installments"}');
