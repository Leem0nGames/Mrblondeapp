
import { redirect } from 'next/navigation';

export default function OnboardingPage() {
  // This route is deprecated and is no longer used.
  // Redirect to the main login page as a fallback.
  redirect('/login');
}
