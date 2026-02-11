'use server';

import { z } from 'zod';

const CuitApiResponseSchema = z.object({
    nombre: z.string(),
    tipoClave: z.string(),
    estadoClave: z.string(),
    tipoPersona: z.string(),
    domicilio: z.array(z.object({
        direccion: z.string(),
        localidad: z.string(),
        codPostal: z.string(),
        id_provincia: z.number(),
        tipoDomicilio: z.string(),
    })).optional(),
});

// We'll map the province ID from the API to our province names
const provinceMapping: { [key: number]: string } = {
    0: "Ciudad Autónoma de Buenos Aires",
    1: "Buenos Aires",
    2: "Catamarca",
    3: "Chaco",
    4: "Chubut",
    5: "Córdoba",
    6: "Corrientes",
    7: "Entre Ríos",
    8: "Formosa",
    9: "Jujuy",
    10: "La Pampa",
    11: "La Rioja",
    12: "Mendoza",
    13: "Misiones",
    14: "Neuquén",
    15: "Río Negro",
    16: "Salta",
    17: "San Juan",
    18: "San Luis",
    19: "Santa Cruz",
    20: "Santa Fe",
    21: "Santiago del Estero",
    22: "Tierra del Fuego",
    23: "Tucumán",
};


export async function getCuitData(cuit: string): Promise<{ data?: any; error?: string }> {
  const apiKey = process.env.CUIT_API_TOKEN;

  if (!apiKey) {
    console.error("CUIT_API_TOKEN environment variable is not set.");
    return { error: "El servicio de búsqueda de CUIT no está configurado en el servidor." };
  }

  try {
    const response = await fetch(`https://sistemaintegrado.com/api/v1/person/${cuit}`, {
      method: 'GET',
      headers: {
        'Authorization': `Bearer ${apiKey}`,
        'Content-Type': 'application/json',
      },
      cache: 'no-store', // Don't cache CUIT lookups
    });

    if (!response.ok) {
        if (response.status === 404) {
            return { error: `No se encontró información para el CUIT ${cuit}.` };
        }
        throw new Error(`API error: ${response.status} ${response.statusText}`);
    }

    const rawData = await response.json();
    const parsedData = CuitApiResponseSchema.safeParse(rawData);

    if (!parsedData.success) {
        console.error("Error parsing CUIT API response:", parsedData.error);
        return { error: "La respuesta de la API de CUIT no tuvo el formato esperado." };
    }

    const fiscalAddress = parsedData.data.domicilio?.find(d => d.tipoDomicilio === 'FISCAL');
    
    // Map the response to our form's structure
    const result = {
        razonSocial: parsedData.data.nombre,
        condicionFiscal: parsedData.data.tipoPersona === 'FISICA' ? 'Monotributista' : 'Responsable Inscripto', // This is an assumption, might need adjustment
        provincia: fiscalAddress ? provinceMapping[fiscalAddress.id_provincia] : '',
        localidad: fiscalAddress ? fiscalAddress.localidad : '',
        calle: fiscalAddress ? fiscalAddress.direccion.replace(/\s\d+$/, '').trim() : '',
        numero: fiscalAddress ? fiscalAddress.direccion.match(/\d+$/)?.[0] || '' : '',
    };

    return { data: result };

  } catch (error: any) {
    console.error("Failed to fetch CUIT data:", error.message);
    return { error: "No se pudo conectar con el servicio de búsqueda de CUIT." };
  }
}
