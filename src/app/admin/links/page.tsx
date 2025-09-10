
"use client";

import { useState, useTransition, useEffect } from "react";
import {
  Card,
  CardContent,
  CardDescription,
  CardHeader,
  CardTitle,
} from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import { generateOrderLink, getAgreements } from "@/app/actions/admin.actions";
import { useToast } from "@/hooks/use-toast";
import { Copy } from "lucide-react";
import type { Agreement } from "@/types";
import { Skeleton } from "@/components/ui/skeleton";

export default function GenerateLinkPage() {
  const [agreements, setAgreements] = useState<Agreement[]>([]);
  const [selectedAgreementId, setSelectedAgreementId] = useState<string>("");
  const [clientName, setClientName] = useState("");
  const [generatedLink, setGeneratedLink] = useState<string | null>(null);
  const [isPending, startTransition] = useTransition();
  const [isLoadingAgreements, startAgreementsLoading] = useTransition();
  const { toast } = useToast();

  useEffect(() => {
    startAgreementsLoading(async () => {
      const { data, error } = await getAgreements();
      if (error) {
        toast({
          title: "Error",
          description: "Could not fetch agreements.",
          variant: "destructive",
        });
      } else {
        setAgreements(data ?? []);
      }
    });
  }, [toast]);

  const handleSubmit = (e: React.FormEvent<HTMLFormElement>) => {
    e.preventDefault();
    if (!clientName) {
      toast({
        title: "Error",
        description: "Please enter a client name.",
        variant: "destructive",
      });
      return;
    }
     if (!selectedAgreementId) {
      toast({
        title: "Error",
        description: "Please select an agreement.",
        variant: "destructive",
      });
      return;
    }
    startTransition(async () => {
      const result = await generateOrderLink(selectedAgreementId, clientName);
      if (result.error) {
        toast({
          title: "Error generating link",
          description: result.error.message,
          variant: "destructive",
        });
        setGeneratedLink(null);
      } else {
        setGeneratedLink(result.link);
        toast({
          title: "Link generated successfully!",
        });
      }
    });
  };

  const copyToClipboard = () => {
    if (generatedLink) {
      navigator.clipboard.writeText(generatedLink);
      toast({ title: "Link copied to clipboard!" });
    }
  };

  return (
    <div className="grid flex-1 items-start gap-4 md:gap-8">
      <h1 className="text-2xl font-bold">Generar Enlace de Pedido</h1>
      <Card className="w-full max-w-lg mx-auto">
        <CardHeader>
          <CardTitle>Generar Enlace de Pedido</CardTitle>
          <CardDescription>
            Crea un enlace único para que un cliente haga un pedido basado en un convenio.
          </CardDescription>
        </CardHeader>
        <CardContent>
          <form onSubmit={handleSubmit} className="space-y-4">
            <div className="space-y-2">
              <Label htmlFor="client-name">Nombre del Cliente</Label>
              <Input
                id="client-name"
                placeholder="e.g., Salon Estilo"
                value={clientName}
                onChange={(e) => setClientName(e.target.value)}
                required
              />
            </div>
            <div className="space-y-2">
              <Label htmlFor="agreement">Convenio</Label>
              {isLoadingAgreements ? <Skeleton className="h-10 w-full" /> : (
                  <Select
                    value={selectedAgreementId}
                    onValueChange={setSelectedAgreementId}
                  >
                    <SelectTrigger id="agreement">
                      <SelectValue placeholder="Selecciona un convenio" />
                    </SelectTrigger>
                    <SelectContent>
                      {agreements.map((agreement) => (
                          <SelectItem key={agreement.id} value={agreement.id}>{agreement.agreement_name}</SelectItem>
                      ))}
                    </SelectContent>
                  </Select>
              )}
            </div>
            <Button type="submit" className="w-full" disabled={isPending || isLoadingAgreements}>
              {isPending ? "Generando..." : "Generar Enlace"}
            </Button>
          </form>

          {generatedLink && (
            <div className="mt-6 space-y-2">
              <Label>Enlace Generado</Label>
              <div className="flex items-center gap-2">
                <Input
                  type="text"
                  readOnly
                  value={generatedLink}
                  className="bg-muted"
                />
                <Button
                  variant="outline"
                  size="icon"
                  onClick={copyToClipboard}
                >
                  <Copy className="h-4 w-4" />
                </Button>
              </div>
              <p className="text-xs text-muted-foreground">
                Este enlace expirará en 24 horas.
              </p>
            </div>
          )}
        </CardContent>
      </Card>
    </div>
  );
}
