"use client";

import { useState, useTransition } from "react";
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
import { generateOrderLink } from "@/app/actions/admin.actions";
import { useToast } from "@/hooks/use-toast";
import { Copy } from "lucide-react";

export default function GenerateLinkPage() {
  const [clientType, setClientType] = useState<"barberia" | "distribuidor">(
    "barberia"
  );
  const [clientName, setClientName] = useState("");
  const [generatedLink, setGeneratedLink] = useState<string | null>(null);
  const [isPending, startTransition] = useTransition();
  const { toast } = useToast();

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
    startTransition(async () => {
      const result = await generateOrderLink(clientType, clientName);
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
    <Card className="w-full max-w-lg mx-auto">
      <CardHeader>
        <CardTitle>Generate Order Link</CardTitle>
        <CardDescription>
          Create a unique link for a client to place an order.
        </CardDescription>
      </CardHeader>
      <CardContent>
        <form onSubmit={handleSubmit} className="space-y-4">
          <div className="space-y-2">
            <Label htmlFor="client-name">Client Name</Label>
            <Input
              id="client-name"
              placeholder="e.g., Salon Estilo"
              value={clientName}
              onChange={(e) => setClientName(e.target.value)}
              required
            />
          </div>
          <div className="space-y-2">
            <Label htmlFor="client-type">Client Type</Label>
            <Select
              value={clientType}
              onValueChange={(
                value: "barberia" | "distribuidor"
              ) => setClientType(value)}
            >
              <SelectTrigger id="client-type">
                <SelectValue placeholder="Select a client type" />
              </SelectTrigger>
              <SelectContent>
                <SelectItem value="barberia">Barbería</SelectItem>
                <SelectItem value="distribuidor">Distribuidor</SelectItem>
              </SelectContent>
            </Select>
          </div>
          <Button type="submit" className="w-full" disabled={isPending}>
            {isPending ? "Generating..." : "Generate Link"}
          </Button>
        </form>

        {generatedLink && (
          <div className="mt-6 space-y-2">
            <Label>Generated Link</Label>
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
              This link will expire in 24 hours.
            </p>
          </div>
        )}
      </CardContent>
    </Card>
  );
}
