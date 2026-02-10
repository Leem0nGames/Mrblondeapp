
import { redirect } from 'next/navigation';

export default function PricelistsRedirectPage() {
  redirect('/admin/commercial-settings?tab=pricelists');
}
