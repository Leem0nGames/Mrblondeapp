
'use server';

import { z } from 'zod';
import { provinces } from '@/lib/geo-data';

// Esquema de validación para la respuesta de la API de afip.dev
const AfipDevResponseSchema = z.object({
  success: z.boolean(),
  data: z.object({
    name: z.string(),
    taxpayerType: z.string().optional(),
    domicilio: z.array(z.object({
      address: z.string(),
      city: z.string(),
      province: z.string(),
      postalCode: z.string(),
      type: z.string(),
    })).optional(),
  }).optional(),
  error: z.object({
    message: z.string(),
  }).optional(),
});


const normalizeProvinceName = (apiProvince: string): string => {
    if (!apiProvince) return '';
    return apiProvince
        .toLowerCase()
        .split(' ')
        .map(word => word.charAt(0).toUpperCase() + word.slice(1))
        .join(' ');
};

const mapTaxpayerType = (apiType?: string): string => {
    if (!apiType) return '';
    if (apiType.toLowerCase().includes('responsable inscripto')) return 'Responsable Inscripto';
    if (apiType.toLowerCase().includes('monotributista')) return 'Monotributista';
    if (apiType.toLowerCase().includes('consumidor final')) return 'Consumidor Final';
    if (apiType.toLowerCase().includes('exento')) return 'Exento';
    return apiType;
}

export async function getCuitData(cuit: string): Promise<{ data?: any; error?: string }> {
  try {
    const response = await fetch(`https://api.afip.dev/v1/taxpayer?cuit=${cuit}`, {
      method: 'GET',
      headers: {
        'Content-Type': 'application/json',
      },
      cache: 'no-store',
    });

    if (!response.ok) {
        if (response.status === 404) {
            return { error: `No se encontró información para el CUIT ${cuit}.` };
        }
        const errorData = await response.json();
        throw new Error(errorData.error?.message || `Error en la API: ${response.status}`);
    }

    const rawData = await response.json();
    const parsedData = AfipDevResponseSchema.safeParse(rawData);

    if (!parsedData.success || !parsedData.data.success || !parsedData.data.data) {
        console.error("Error parsing CUIT API response:", parsedData.error);
        return { error: parsedData.data?.error?.message || "La respuesta de la API no tuvo el formato esperado." };
    }

    const fiscalAddress = parsedData.data.data.domicilio?.find(d => d.type === 'FISCAL');
    const normalizedProvince = fiscalAddress ? normalizeProvinceName(fiscalAddress.province) : '';
    const provincia = provinces.find(p => p === normalizedProvince) || normalizedProvince;

    const result = {
        razonSocial: parsedData.data.data.name,
        condicionFiscal: mapTaxpayerType(parsedData.data.data.taxpayerType),
        provincia: provincia,
        localidad: fiscalAddress ? normalizeProvinceName(fiscalAddress.city) : '',
        calle: fiscalAddress ? fiscalAddress.address.replace(/\s\d+$/, '').trim() : '',
        numero: fiscalAddress ? fiscalAddress.address.match(/\d+$/)?.[0] || '' : '',
    };

    return { data: result };

  } catch (error: any) {
    console.error("Failed to fetch CUIT data:", error.message);
    return { error: "No se pudo conectar con el servicio de búsqueda de CUIT." };
  }
}
