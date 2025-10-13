-- Este script es para popular la tabla 'products' y otras con datos de ejemplo.
-- Ejecútalo después de haber ejecutado schema.sql.
-- El schema.sql ya limpia las tablas, por lo que este script puede ejecutarse de forma segura.

INSERT INTO products (name, description, base_price, stock, category) VALUES
('DesertStyle Pomada efecto mate 50 grs', 'Pomada efecto mate', 14766.67, 0, 'Hairstyle'),
('Polvo Stardust 10grs', 'Polvo styling efecto mate', 14766.67, 0, 'Hairstyle'),
('OldSchool 100 grs', 'Pomada de fijación media/alta y brillo medio', 15972.97, 0, 'Hairstyle'),
('Liquid Pomade 120 ml', 'Pomada líquida para modelar cabello', 12310.81, 0, 'Hairstyle'),
('Shampoo 2 en 1 para el crecimiento 200 cc', 'Shampoo + acondicionador 2 en 1', 15063.96, 0, 'Hairstyle'),
('OldSchool 50 grs', 'Pomada de fijación media/alta y brillo medio', 12009.01, 0, 'Hairstyle'),
('El Capitán aceite para barba 20 ml N°3', 'Aceite para barba', 14324.32, 0, 'FacialBeard'),
('El Capitán aceite para barba 20 ml N°1', 'Aceite para barba', 14324.32, 0, 'FacialBeard'),
('Kit Premium para Barba N°1', 'Kit completo para barba', 26090.09, 0, 'FacialBeard'),
('OG Dandy After Shave 100 grs', 'After shave tradicional', 11879.28, 0, 'FacialBeard'),
('Kit Premium para Barba N°2', 'Kit completo para barba', 26090.09, 0, 'FacialBeard'),
('El Capitán aceite para barba 20 ml N°2', 'Aceite para barba', 14324.32, 0, 'FacialBeard'),
('Kit Premium para Barba N°3', 'Kit completo para barba', 27018.92, 0, 'FacialBeard'),
('Kit Premium Cabello N°2', 'Kit cabello', 27536.04, 0, 'Hairstyle'),
('Kit Premium Cabello N°4', 'Kit cabello', 26628.65, 0, 'Hairstyle'),
('Kit Premium Cabello N°3', 'Kit cabello', 27705.41, 0, 'Hairstyle'),
('Kit Premium Cabello N°1', 'Kit cabello', 24584.23, 0, 'Hairstyle'),
('Kit Premium para Barba N°4', 'Kit completo para barba', 30794.14, 0, 'Hairstyle'),
('Caja Exhibidora Mr BLONDE', 'Exhibidor para puntos de venta', 30794.14, 0, 'Merchandising'),
('Crystal gel de afeitar 250 grs', 'Gel de afeitar profesional', 7820.18, 0, 'Professional'),
('Crème à Raser 400 grs', 'Crema de afeitado tradicional', 14172.71, 0, 'Professional'),
('Capa Mr Blonde', 'Capa para barbería confeccionada en tela liviana', 12610.35, 0, 'Merchandising');
