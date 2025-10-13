-- Este script es para popular la tabla 'products' con datos de ejemplo.
-- Ejecútalo DESPUÉS de haber ejecutado schema.sql.

-- Limpia la tabla antes de insertar para evitar duplicados si se ejecuta varias veces.
DELETE FROM products;

INSERT INTO products (name, description, base_price, category) VALUES
('DesertStyle Pomada efecto mate 50 grs', 'Pomada efecto mate', 14766.67, 'Hairstyle'),
('Polvo Stardust 10grs', 'Polvo styling efecto mate', 14766.67, 'Hairstyle'),
('OldSchool 100 grs', 'Pomada de fijación media/alta y brillo medio', 15972.97, 'Hairstyle'),
('Liquid Pomade 120 ml', 'Pomada líquida para modelar cabello', 12310.81, 'Hairstyle'),
('Shampoo 2 en 1 para el crecimiento 200 cc', 'Shampoo + acondicionador 2 en 1', 15063.96, 'Hairstyle'),
('OldSchool 50 grs', 'Pomada de fijación media/alta y brillo medio', 12009.01, 'Hairstyle'),
('El Capitán aceite para barba 20 ml N°3', 'Aceite para barba', 14324.32, 'FacialBeard'),
('El Capitán aceite para barba 20 ml N°1', 'Aceite para barba', 14324.32, 'FacialBeard'),
('Kit Premium para Barba N°1', 'Kit completo para barba', 26090.09, 'FacialBeard'),
('OG Dandy After Shave 100 grs', 'After shave tradicional', 11879.28, 'FacialBeard'),
('Kit Premium para Barba N°2', 'Kit completo para barba', 26090.09, 'FacialBeard'),
('El Capitán aceite para barba 20 ml N°2', 'Aceite para barba', 14324.32, 'FacialBeard'),
('Kit Premium para Barba N°3', 'Kit completo para barba', 27018.92, 'FacialBeard'),
('Kit Premium Cabello N°2', 'Kit cabello', 27536.04, 'Hairstyle'),
('Kit Premium Cabello N°4', 'Kit cabello', 26628.65, 'Hairstyle'),
('Kit Premium Cabello N°3', 'Kit cabello', 27705.41, 'Hairstyle'),
('Kit Premium Cabello N°1', 'Kit cabello', 24584.23, 'Hairstyle'),
('Kit Premium para Barba N°4', 'Kit completo para barba', 30794.14, 'Hairstyle'),
('Caja Exhibidora Mr BLONDE', 'Exhibidor para puntos de venta', 30794.14, 'Merchandising'),
('Crystal gel de afeitar 250 grs', 'Gel de afeitar profesional', 7820.18, 'Professional'),
('Crème à Raser 400 grs', 'Crema de afeitado tradicional', 14172.71, 'Professional'),
('Capa Mr Blonde', 'Capa para barbería confeccionada en tela liviana', 12610.35, 'Merchandising');
