import {accountDeletionHandler} from './core.ts';
Deno.serve(accountDeletionHandler({
  url:Deno.env.get('SUPABASE_URL')!,
  serviceKey:Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
}));
