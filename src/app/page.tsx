import Link from 'next/link';
import { Button } from '@/components/ui/button';
import { ArrowRight, ShoppingCart, SlidersHorizontal } from 'lucide-react';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';

export default function Home() {
  return (
    <div className="flex flex-col min-h-screen">
      <header className="container mx-auto px-4 sm:px-6 lg:px-8 py-4">
        <div className="flex justify-between items-center">
          <h1 className="text-2xl font-bold font-headline text-primary">Blonde Orders</h1>
          <Button asChild variant="outline">
            <Link href="/admin">Admin Login</Link>
          </Button>
        </div>
      </header>
      <main className="flex-grow">
        <section className="relative text-center py-20 lg:py-32 bg-secondary/30">
          <div className="absolute inset-0 bg-grid-slate-100 [mask-image:linear-gradient(0deg,#fff,rgba(255,255,255,0.6))] dark:[mask-image:linear-gradient(0deg,#fff,rgba(255,255,255,0.05))]"></div>
           <div className="container mx-auto px-4 sm:px-6 lg:px-8 relative">
            <h2 className="text-4xl lg:text-6xl font-extrabold font-headline tracking-tight text-primary">
              Effortless Ordering, Elevated.
            </h2>
            <p className="mt-4 max-w-2xl mx-auto text-lg lg:text-xl text-muted-foreground">
              A modern solution for beauty suppliers. Streamline your order process with personalized links and intelligent promotions.
            </p>
            <div className="mt-8 flex justify-center gap-4">
              <Button size="lg" asChild>
                <Link href="/admin">
                  Go to Admin Panel <ArrowRight className="ml-2 h-4 w-4" />
                </Link>
              </Button>
            </div>
          </div>
        </section>

        <section className="py-16 lg:py-24 bg-background">
          <div className="container mx-auto px-4 sm:px-6 lg:px-8">
            <div className="text-center mb-12">
              <h3 className="text-3xl font-bold font-headline">How It Works</h3>
              <p className="mt-2 text-muted-foreground">A simple, three-step process to streamline your sales.</p>
            </div>
            <div className="grid grid-cols-1 md:grid-cols-3 gap-8 text-center">
              <Card>
                <CardHeader>
                  <div className="mx-auto flex h-12 w-12 items-center justify-center rounded-full bg-secondary">
                    <SlidersHorizontal className="h-6 w-6 text-secondary-foreground" />
                  </div>
                  <CardTitle className="mt-4">1. Configure &amp; Share</CardTitle>
                </CardHeader>
                <CardContent>
                  <p className="text-muted-foreground">
                    Generate unique, personalized order links for your clients from the admin dashboard.
                  </p>
                </CardContent>
              </Card>
              <Card>
                <CardHeader>
                  <div className="mx-auto flex h-12 w-12 items-center justify-center rounded-full bg-secondary">
                    <ShoppingCart className="h-6 w-6 text-secondary-foreground" />
                  </div>
                  <CardTitle className="mt-4">2. Client Places Order</CardTitle>
                </CardHeader>
                <CardContent>
                  <p className="text-muted-foreground">
                    Clients use the link to access their custom form, add products, and see dynamic pricing.
                  </p>
                </CardContent>
              </Card>
              <Card>
                <CardHeader>
                  <div className="mx-auto flex h-12 w-12 items-center justify-center rounded-full bg-secondary">
                    <svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" className="h-6 w-6 text-secondary-foreground"><path d="m21.3 3.7-2.2 2.2c-.4-.2-.9-.3-1.3-.3-2.3 0-4.2 1.9-4.2 4.2s1.9 4.2 4.2 4.2c2.3 0 4.2-1.9 4.2-4.2 0-.4-.1-.9-.3-1.3l2.2-2.2"/><path d="m15.8 15.8-2.2 2.2c-.4-.2-.9-.3-1.3-.3-2.3 0-4.2 1.9-4.2 4.2s1.9 4.2 4.2 4.2 4.2-1.9 4.2-4.2c0-.4-.1-.9-.3-1.3l2.2-2.2"/><path d="m8.2 8.2-2.2 2.2c-.4-.2-.9-.3-1.3-.3-2.3 0-4.2 1.9-4.2 4.2s1.9 4.2 4.2 4.2 4.2-1.9 4.2-4.2c0-.4-.1-.9-.3-1.3l2.2-2.2"/></svg>
                  </div>
                  <CardTitle className="mt-4">3. Confirm via WhatsApp</CardTitle>
                </CardHeader>
                <CardContent>
                  <p className="text-muted-foreground">
                    A pre-formatted message is generated and sent via WhatsApp to finalize the order offline.
                  </p>
                </CardContent>
              </Card>
            </div>
          </div>
        </section>
      </main>

      <footer className="bg-secondary/30">
        <div className="container mx-auto px-4 sm:px-6 lg:px-8 py-6 text-center text-muted-foreground">
          <p>&copy; {new Date().getFullYear()} Blonde Orders. All rights reserved.</p>
        </div>
      </footer>
    </div>
  );
}
