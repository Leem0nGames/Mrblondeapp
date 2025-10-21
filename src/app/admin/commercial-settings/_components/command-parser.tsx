
'use client';

import { useState, useTransition } from 'react';
import { useRouter } from 'next/navigation';
import { Command, Sparkles, Loader2 } from 'lucide-react';

import { Input } from '@/components/ui/input';
import { Button } from '@/components/ui/button';
import { useToast } from '@/hooks/use-toast';
import { commandParser } from '@/ai/flows/command-parser-flow';
import { upsertPromotion } from '@/app/admin/actions/promotions.actions';
import { upsertPriceList } from '@/app/admin/actions/pricelists.actions';
import { upsertSalesCondition } from '@/app/admin/actions/sales-conditions.actions';

export function CommandParser() {
  const [command, setCommand] = useState('');
  const [isPending, startTransition] = useTransition();
  const router = useRouter();
  const { toast } = useToast();

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!command.trim()) return;

    startTransition(async () => {
      try {
        const result = await commandParser({ command });

        if (!result || !result.entity) {
          throw new Error('La IA no pudo devolver una entidad válida.');
        }

        let upsertPromise;
        switch (result.entity) {
          case 'promotion':
            upsertPromise = upsertPromotion(result.data);
            break;
          case 'pricelist':
             const { base_price_list_id, ...restOfData } = result.data;
             const payload = {
                ...restOfData,
                base_price_list_id: base_price_list_id || null, // Ensure null if it's empty string
                // You might need to handle creation of prices in a separate step or flow for pricelists
             };
             upsertPromise = upsertPriceList(payload);
            break;
          case 'sales_condition':
            upsertPromise = upsertSalesCondition(result.data);
            break;
          default:
            throw new Error('Tipo de entidad no reconocido.');
        }

        const { error } = await upsertPromise;
        if (error) {
          throw new Error(error.message);
        }

        toast({
          title: '¡Éxito!',
          description: `La entidad '${result.entity}' se creó correctamente.`,
        });

        setCommand('');
        router.refresh();
      } catch (error: any) {
        console.error(error);
        toast({
          title: 'Error de Comando',
          description:
            error.message ||
            'No se pudo interpretar o ejecutar el comando.',
          variant: 'destructive',
        });
      }
    });
  };

  return (
    <form
      onSubmit={handleSubmit}
      className="relative flex-1"
    >
      <Command className="absolute left-2.5 top-2.5 h-4 w-4 text-muted-foreground" />
      <Input
        type="text"
        placeholder='Crear promo 2x1 en Ceras o "nueva lista con 10% off sobre..."'
        className="w-full rounded-lg bg-background pl-8"
        value={command}
        onChange={(e) => setCommand(e.target.value)}
        disabled={isPending}
      />
      <Button
        type="submit"
        size="icon"
        className="absolute right-1 top-1 h-7 w-7"
        disabled={isPending || !command.trim()}
      >
        {isPending ? (
          <Loader2 className="h-4 w-4 animate-spin" />
        ) : (
          <Sparkles className="h-4 w-4" />
        )}
        <span className="sr-only">Ejecutar Comando</span>
      </Button>
    </form>
  );
}
