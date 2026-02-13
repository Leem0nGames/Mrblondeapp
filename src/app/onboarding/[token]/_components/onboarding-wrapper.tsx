
"use client";

import { useState } from 'react';
import { useRouter } from 'next/navigation';
import { OnboardingForm } from './onboarding-form';
import { CheckCircle2 } from 'lucide-react';

function OnboardingSuccess({ clientName }: { clientName: string }) {
    return (
        <div className="text-center space-y-4 animate-in fade-in-50">
            <CheckCircle2 className="h-16 w-16 text-green-500 mx-auto" />
            <h2 className="text-2xl font-bold">¡Gracias, {clientName}!</h2>
            <p className="text-muted-foreground">
                Tus datos fueron guardados. En un momento serás redirigido para que realices tu primer pedido.
            </p>
        </div>
    )
}

export function OnboardingWrapper({ client }: { client: any }) {
    const router = useRouter();
    const [isSuccess, setIsSuccess] = useState(false);
    const [submittedName, setSubmittedName] = useState("");

    const handleSuccess = (name: string) => {
        setSubmittedName(name);
        setIsSuccess(true);
        if (client.agreement_id) {
            // Redirect after a short delay so the user can see the message.
            setTimeout(() => {
                router.push(`/pedido/${client.agreement_id}`);
            }, 2500); // 2.5 seconds delay
        }
    };

    return isSuccess 
        ? <OnboardingSuccess clientName={submittedName} /> 
        : <OnboardingForm client={client} onSuccess={handleSuccess} />
}
