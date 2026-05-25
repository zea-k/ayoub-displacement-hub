import { corsHeaders } from 'npm:@supabase/supabase-js@2/cors';

const CLOUD_NAME = Deno.env.get('CLOUDINARY_CLOUD_NAME') ?? '';
const API_KEY = Deno.env.get('CLOUDINARY_API_KEY') ?? '';
const API_SECRET = Deno.env.get('CLOUDINARY_API_SECRET') ?? '';

const ALLOWED_FOLDERS = new Set([
  'discover-posts',
  'store-products',
  'profile-images',
  'banners',
  'system-assets',
  'product-stories',
]);

async function sha1Hex(input: string): Promise<string> {
  const buf = await crypto.subtle.digest('SHA-1', new TextEncoder().encode(input));
  return Array.from(new Uint8Array(buf)).map((b) => b.toString(16).padStart(2, '0')).join('');
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });

  try {
    if (!CLOUD_NAME || !API_KEY || !API_SECRET) {
      return new Response(JSON.stringify({ error: 'Cloudinary not configured' }), {
        status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    const body = await req.json().catch(() => ({}));
    const folder = ALLOWED_FOLDERS.has(body.folder) ? body.folder : 'system-assets';
    const timestamp = Math.floor(Date.now() / 1000);

    // Params to sign (alphabetical). We let Cloudinary do f_auto/q_auto on delivery.
    const params: Record<string, string | number> = { folder, timestamp };
    const toSign = Object.keys(params)
      .sort()
      .map((k) => `${k}=${params[k]}`)
      .join('&');
    const signature = await sha1Hex(toSign + API_SECRET);

    return new Response(
      JSON.stringify({ signature, timestamp, apiKey: API_KEY, cloudName: CLOUD_NAME, folder }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  } catch (e) {
    return new Response(JSON.stringify({ error: String(e) }), {
      status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }
});
