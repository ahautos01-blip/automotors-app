-- Daily aggregate-only retention, even if no further usage is recorded.
select cron.schedule('automotors-market-usage-retention','17 3 * * *',
  $job$delete from private.market_usage_totals where day < (now() at time zone 'UTC')::date - 30$job$);
