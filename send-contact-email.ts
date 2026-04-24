// supabase/functions/send-contact-email/index.ts
// Deploy: supabase functions deploy send-contact-email
//
// Required secrets (set in Supabase Dashboard → Edge Functions → Secrets):
//   RESEND_API_KEY  — get free at resend.com (100 emails/day free)
//   ADMIN_EMAIL     — your email e.g. thasshanrao@gmail.com
//
// Resend setup:
//   1. Sign up at resend.com (free)
//   2. Go to API Keys → Create API Key
//   3. Add it as RESEND_API_KEY secret in Supabase

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });

  try {
    const { name, email, subject, message } = await req.json();

    const RESEND_API_KEY = Deno.env.get('RESEND_API_KEY');
    const ADMIN_EMAIL    = Deno.env.get('ADMIN_EMAIL') || 'thasshanrao@gmail.com';

    if (!RESEND_API_KEY) {
      // No email key set — silently succeed so form still works
      return new Response(JSON.stringify({ ok: true, note: 'No email key configured' }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      });
    }

    const html = `
      <div style="font-family:sans-serif;max-width:560px;margin:0 auto">
        <div style="background:#e8521a;padding:20px 24px;border-radius:10px 10px 0 0">
          <h2 style="color:white;margin:0;font-size:1.2rem">📩 New Enquiry — Servify</h2>
        </div>
        <div style="background:#fff;border:1px solid #e8e6e0;border-top:none;padding:24px;border-radius:0 0 10px 10px">
          <table style="width:100%;border-collapse:collapse">
            <tr><td style="padding:8px 0;color:#888;width:100px">From</td><td style="padding:8px 0;font-weight:600">${name}</td></tr>
            <tr><td style="padding:8px 0;color:#888">Email</td><td style="padding:8px 0"><a href="mailto:${email}" style="color:#e8521a">${email}</a></td></tr>
            <tr><td style="padding:8px 0;color:#888">Subject</td><td style="padding:8px 0">${subject || 'General Enquiry'}</td></tr>
          </table>
          <hr style="border:none;border-top:1px solid #f0ede8;margin:16px 0">
          <p style="color:#333;line-height:1.6;white-space:pre-wrap">${message}</p>
          <hr style="border:none;border-top:1px solid #f0ede8;margin:16px 0">
          <a href="mailto:${email}?subject=Re: ${encodeURIComponent(subject || 'Your Servify Enquiry')}" 
             style="display:inline-block;background:#e8521a;color:white;padding:10px 24px;border-radius:8px;text-decoration:none;font-weight:600">
            ↩ Reply to ${name}
          </a>
        </div>
        <p style="text-align:center;color:#aaa;font-size:0.75rem;margin-top:16px">Servify · servify-wheat.vercel.app</p>
      </div>
    `;

    const res = await fetch('https://api.resend.com/emails', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${RESEND_API_KEY}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        from:    'Servify Enquiries <onboarding@resend.dev>',
        to:      [ADMIN_EMAIL],
        subject: `[Servify] ${subject || 'New Enquiry'} — from ${name}`,
        html,
        reply_to: email,
      }),
    });

    if (!res.ok) {
      const err = await res.text();
      console.error('Resend error:', err);
      // Still return 200 — form submission already saved to DB
      return new Response(JSON.stringify({ ok: true, note: 'Email failed but saved to DB' }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      });
    }

    return new Response(JSON.stringify({ ok: true }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    });

  } catch (err) {
    console.error('send-contact-email error:', err);
    return new Response(JSON.stringify({ ok: true }), { // always 200 — don't break the form
      headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    });
  }
});
