import {listingModerationHandler} from './core.ts';
Deno.serve(listingModerationHandler({url:Deno.env.get('SUPABASE_URL')!,serviceKey:Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,openaiKey:Deno.env.get('OPENAI_API_KEY')??''}));
