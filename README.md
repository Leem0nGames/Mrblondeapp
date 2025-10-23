# Blonde Orders

Welcome to Blonde Orders, a modern, streamlined order management system designed for beauty product suppliers. This application provides a seamless experience for clients (salons, distributors) to place orders and for administrators to manage products, pricing, and promotions.

Built with a powerful stack including Next.js, Supabase, and Tailwind CSS, this MVP is designed for simplicity, scalability, and a world-class user experience.

## Core Features

- **Dual Client Onboarding**: Admins can create clients manually for quick setup or generate unique invitation links for clients to self-register, saving administrative time.
- **Dynamic Link Generation**: Admins can generate unique ordering links for clients based on commercial agreements.
- **Client-Specific Pricing & Promotions**: The system automatically calculates prices and applies promotions based on assigned commercial agreements.
- **Intelligent Admin Commands**: An integrated AI tool allows admins to create promotions, price lists, and more using natural language commands (e.g., "create 2x1 promo for all waxes").
- **AI-Powered Client Analysis**: Generate strategic insights, opportunities, and risks for any client based on their purchase history.
- **Customizable Branding**: Easily upload your company logo to be displayed across the application.
- **Seamless Order Submission**: Clients can preview their order with all calculations and send a pre-formatted summary directly to the company's WhatsApp.
- **Comprehensive Admin Dashboard**: A secure area for admins to manage the entire product catalog, pricing rules, promotions, and client agreements.

## Tech Stack

- **Framework**: Next.js 14+ (App Router)
- **UI**: React 18, TypeScript, Tailwind CSS, shadcn/ui
- **Backend & Database**: Supabase (PostgreSQL, Auth, Storage)
- **AI Features**: Google AI with Genkit
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

**C. Set Up Supabase & Environment**

1.  **Crucial Step**: Follow the complete database and environment setup guide in the `INSTRUCCIONES.md` file located in the root of this project. It contains the necessary SQL script and instructions for environment variables (`.env.local`).

### 3. Running the Development Server

Start the app in development mode:

```bash
npm run dev
```

- The application will be available at `http://localhost:9003`.
- The first time you run the app, you will be redirected to `/signup` to create the main administrator account.

## Deployment

This project is optimized for deployment on [Vercel](https://vercel.com/).

1.  **Push to GitHub/GitLab/Bitbucket**: Ensure your code is on a Git provider.
2.  **Import Project on Vercel**: From your Vercel dashboard, import the repository.
3.  **Configure Environment Variables (CRITICAL STEP)**:
    - In your Vercel project's settings, navigate to the **Environment Variables** section.
    - You **MUST** add the same three environment variables from your local `.env.local` file:
      - `NEXT_PUBLIC_SUPABASE_URL`
      - `NEXT_PUBLIC_SUPABASE_ANON_KEY`
      - `SUPABASE_SERVICE_ROLE_KEY`
    - If you are using the maps feature, you must also add:
      - `NEXT_PUBLIC_GOOGLE_MAPS_API_KEY`
    - Copy the values from your local file (or directly from your Supabase project settings) into Vercel. Ensure there are no extra spaces or characters.
    - **This step is mandatory. Without these variables, the deployed application will show an "Internal Server Error".**
4.  **Deploy**: Trigger a new deployment in Vercel. With the environment variables now correctly configured, the build and deployment will succeed and the application will be accessible.

Once deployed, your application will be live!
