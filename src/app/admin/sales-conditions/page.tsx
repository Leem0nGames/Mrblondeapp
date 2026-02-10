
import { redirect } from 'next/navigation';

export default function SalesConditionsRedirectPage() {
  redirect('/admin/commercial-settings?tab=sales-conditions');
}
