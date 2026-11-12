type Subscription = {
  product_id?: string;
  status?: string;
  started_at?: string | null;
  created_at?: string | null;
  expires_at?: string | null;
};

export function hasActiveLookupSubscription(rows: Subscription[], now = Date.now()): boolean {
  return rows.some((row) => {
    const start = Date.parse(row.started_at ?? row.created_at ?? '');
    const expiry = Date.parse(row.expires_at ?? '');
    return ['automotors_pack_20', 'automotors_pro_monthly_199'].includes(row.product_id ?? '') &&
      ['active', 'grace_period'].includes(row.status ?? '') &&
      Number.isFinite(start) && start <= now && Number.isFinite(expiry) && expiry > now;
  });
}
