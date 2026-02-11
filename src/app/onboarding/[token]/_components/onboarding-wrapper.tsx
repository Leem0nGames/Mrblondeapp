
'use client';

import { useState } from 'react';
import { OnboardingForm } from './onboarding-form';
import { CheckCircle2 } from 'lucide-react';

function OnboardingSuccess() {
    return (
        <div className="text-center space-y-4">
            <CheckCircle2 className="h-16 w-16 text-green-500 mx-auto" />
            <h2 className="text-2xl font-bold">¡Datos Recibidos!</h2>
            <p className="text-muted-foreground">
                Muchas gracias por completar tu información. Un representante comercial se pondrá en contacto contigo a la brevedad para finalizar el alta y asignarte tu convenio.
            </p>
        </div>
    )
}

export function OnboardingWrapper({ client }: { client: any }) {
    const [isSuccess, setIsSuccess] = useState(false);
    return isSuccess ? <OnboardingSuccess /> : <OnboardingForm client={client} onSuccess={() => setIsSuccess(true)} />
}
