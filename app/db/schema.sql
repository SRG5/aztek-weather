CREATE TABLE IF NOT EXISTS saved_forecasts (
  id BIGSERIAL PRIMARY KEY,
  user_name TEXT NOT NULL,
  city TEXT NOT NULL,
  forecast_json JSONB NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_saved_forecasts_created_at
  ON saved_forecasts (created_at DESC);