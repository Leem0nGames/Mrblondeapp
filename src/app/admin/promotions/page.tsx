
import { redirect } from 'next/navigation';

export default function PromotionsRedirectPage() {
  redirect('/admin/commercial-settings?tab=promotions');
}
