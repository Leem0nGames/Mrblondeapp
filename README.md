# Blonde Orders

Welcome to Blonde Orders, a modern, streamlined order management system designed for beauty product suppliers. This application provides a seamless experience for clients (salons, distributors) to place orders and for administrators to manage products, pricing, and promotions.

Built with a powerful stack including Next.js, Supabase, and Tailwind CSS, this MVP is designed for simplicity, scalability, and a world-class user experience.

## Core Features

- **Dynamic Link Generation**: Admins can generate unique, temporary (24-hour) links for clients, leading them to a personalized order form.
- **Client-Specific Pricing**: The system automatically calculates prices based on client type (`barberia`, `distribuidor`) and custom agreements.
- **Intelligent Promotion Suggestions**: An integrated AI tool analyzes the shopping cart and suggests the most advantageous promotions to the client, helping to increase order value.
- **Seamless Order Submission**: Clients can preview their order with all calculations and send a pre-formatted summary directly to the company's WhatsApp.
- **Comprehensive Admin Dashboard**: A secure area for admins to manage the entire product catalog, pricing rules, promotions, and client agreements.

## Tech Stack

- **Framework**: Next.js 14+ (App Router)
- **UI**: React 18, TypeScript, Tailwind CSS, shadcn/ui
- **Backend & Database**: Supabase (PostgreSQL, Auth)
- **State Management**: Zustand
- **Forms**: React Hook Form & Zod
- **Icons**: Lucide React

## Getting Started

Follow these instructions to get the project running locally and deployed.

### 1. Prerequisites

- Node.js (v18 or later)
- npm or yarn
- A Supabase account and project.
- Vercel account for deployment.

### 2. Local Setup

**A. Clone the Repository**

```bash
git clone <your-repository-url>
cd blonde-orders
```

**B. Install Dependencies**

```bash
npm install
```

**C. Set Up Supabase**

1.  Create a new project on [Supabase](https://supabase.com/).
2.  Navigate to the **SQL Editor** in your Supabase dashboard.
3.  Open the `database.sql` file from this project, copy its content, and run it in the SQL Editor to create the necessary tables.
4.  Go to **Project Settings > API**. Find your Project URL and `anon` public key.
5.  Go to **Project Settings > Database > Connection string**. Find your Service Role Key (secret).

**D. Configure Environment Variables**

Create a `.env.local` file in the root of the project by copying the example file:

```bash
cp .env.example .env.local
```

Now, fill in the values with your Supabase credentials and your business WhatsApp number:

```
NEXT_PUBLIC_SUPABASE_URL=your_supabase_project_url
NEXT_PUBLIC_SUPABASE_ANON_KEY=your_supabase_anon_key
SUPABASE_SERVICE_ROLE_KEY=your_supabase_service_role_key
NEXT_PUBLIC_WHATSAPP_NUMBER=5491123456789
```

### 3. Running the Development Server

Start the app in development mode:

```bash
npm run dev
```

- The application will be available at `http://localhost:3000`.
- The admin panel is at `http://localhost:3000/admin`. You can create an admin user through your Supabase dashboard's Authentication section and use those credentials to log in.

## Deployment

This project is optimized for deployment on [Vercel](https://vercel.com/).

1.  **Push to GitHub/GitLab/Bitbucket**: Ensure your code is on a Git provider.
2.  **Import Project on Vercel**: From your Vercel dashboard, import the repository.
3.  **Configure Environment Variables**: In the Vercel project settings, add the same environment variables from your `.env.local` file.
4.  **Deploy**: Vercel will automatically detect it's a Next.js app and deploy it.

Once deployed, your application will be live!
