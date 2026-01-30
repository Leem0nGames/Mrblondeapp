
export type AppError = {
  message: string;
  code?: string;
};

export function getSupabaseErrorMessage(error: { message: string; code?: string; details?: string }): string {
  const { message, code, details } = error;

  if (code) {
    switch (code) {
      case '23505':
        if (message.includes('cuit') || details?.includes('cuit')) {
          return 'El CUIT ingresado ya está registrado en nuestro sistema.';
        }
        if (message.includes('email') || details?.includes('email')) {
          return 'El email ya está registrado. Intenta iniciar sesión.';
        }
        if (message.includes('clients_email_key')) {
          return 'El email ya está registrado. Intenta iniciar sesión.';
        }
        if (message.includes('clients_cuit_key')) {
          return 'El CUIT ya está registrado en nuestro sistema.';
        }
        return 'Ya existe un registro con esos datos. Verifica la información ingresada.';

      case '23503':
        if (message.includes('clients_agreement_id_fkey')) {
          return 'El convenio seleccionado no es válido.';
        }
        if (message.includes('orders_client_id_fkey')) {
          return 'El cliente no existe en el sistema.';
        }
        if (message.includes('orders_agreement_id_fkey')) {
          return 'El convenio no es válido.';
        }
        if (message.includes('products_fkey')) {
          return 'El producto no existe.';
        }
        return 'Error de referencia. Verifica que los datos relacionados existan.';

      case '23502':
        if (message.includes('contact_name')) {
          return 'El nombre de contacto es obligatorio.';
        }
        if (message.includes('email')) {
          return 'El email es obligatorio.';
        }
        return 'Falta información obligatoria. Completa todos los campos requeridos.';

      case 'PGRST301':
        return 'Error de autenticación. Tu sesión ha expirado. Vuelve a iniciar sesión.';

      case '42501':
        return 'No tienes permisos para realizar esta acción.';

      case '401':
        return 'Debes iniciar sesión para continuar.';

      case '403':
        return 'No tienes permisos para acceder a este recurso.';

      case '404':
        return 'El recurso solicitado no existe o fue eliminado.';

      case '500':
        return 'Error del servidor. Intenta nuevamente en unos minutos.';

      case '503':
        return 'Servicio temporalmente no disponible. Intenta más tarde.';

      default:
        break;
    }
  }

  if (message.includes('User already registered') || message.includes('already registered')) {
    return 'Este correo electrónico ya está registrado. Intenta iniciar sesión.';
  }

  if (message.includes('Invalid login credentials') || message.includes('Invalid credentials')) {
    return 'Email o contraseña incorrectos.';
  }

  if (message.includes('Email rate limit exceeded') || message.includes('rate limit')) {
    return 'Demasiados intentos. Espera unos minutos antes de volver a intentar.';
  }

  if (message.includes('Password should be at least 6 characters') || message.includes('Password must be')) {
    return 'La contraseña debe tener al menos 6 caracteres.';
  }

  if (message.includes('Invalid email') || message.includes('email must be a valid email')) {
    return 'Ingresa un email válido.';
  }

  if (message.includes('JWToken') || message.includes('jwt')) {
    return 'Tu sesión ha expirado. Vuelve a iniciar sesión.';
  }

  if (message.includes('row-level security') || message.includes('RLS')) {
    return 'No tienes permisos para acceder a estos datos.';
  }

  if (message.includes('connection') || message.includes('network') || message.includes('fetch')) {
    return 'Error de conexión. Verifica tu internet e intenta nuevamente.';
  }

  return message || 'Ocurrió un error. Intenta nuevamente.';
}
