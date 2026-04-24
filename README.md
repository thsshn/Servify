# Servify

> Services, Simplified — connecting customers with trusted local service providers in Malaysia.

## Project Structure

```
servify/
├── index.html              # Homepage + auth modals + listings
├── dashboard.html          # User dashboard (provider & seeker)
├── provider-profile.html   # Provider profile (edit + public seeker view)
├── auth-callback.html      # Supabase OAuth / magic-link callback handler
├── 404.html                # 404 page
├── _redirects              # Netlify SPA redirect rules
├── vercel.json             # Vercel SPA rewrite rules
└── supabase/
    └── functions/
        ├── admin-users/        # Edge function: list all users (admin only)
        ├── admin-ban-user/     # Edge function: ban/unban a user (admin only)
        └── delete-account/     # Edge function: PDPA-compliant account deletion
```

## Deployment

### 1. Supabase Setup
Run `supabase-setup.sql` in your **Supabase Dashboard → SQL Editor**.  
This creates all tables, RLS policies, storage bucket, and the auto-profile trigger.

> ⚠️ Do **not** commit `supabase-setup.sql` to GitHub — it's in `.gitignore`.  
> Keep it locally and run it manually.

After signing up with your admin account, uncomment and run the last query in the SQL file to grant yourself admin role.

### 2. Supabase Auth Settings
In Supabase Dashboard → Authentication → URL Configuration, add:
```
https://yourdomain.com/auth-callback.html
```

### 3. Deploy Edge Functions
```bash
supabase functions deploy admin-users
supabase functions deploy admin-ban-user
supabase functions deploy delete-account
```
Set `SUPABASE_SERVICE_ROLE_KEY` as a secret in Supabase Dashboard → Edge Functions → Secrets.

### 4. Deploy to Vercel / Netlify
- **Vercel**: push to GitHub, import repo — `vercel.json` handles SPA routing automatically.
- **Netlify**: push to GitHub, import repo — `_redirects` handles SPA routing automatically.

## Tech Stack
- Pure HTML/CSS/JS — no build step required
- [Supabase](https://supabase.com) — auth, database, storage, edge functions
- Google Fonts — Syne + DM Sans
