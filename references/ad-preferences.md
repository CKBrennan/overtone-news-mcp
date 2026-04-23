# Ad Preferences

Control which sponsorships appear alongside your news by editing `~/.overtone/preferences.yaml`.

## Configuration

Create or edit `~/.overtone/preferences.yaml`:

```yaml
# Master switch: set to false to disable all sponsorships
sponsorships_enabled: true

# Only show sponsorships from these categories (optional)
# If omitted or empty, all non-blocked categories are allowed
allowed_categories:
  - sports
  - technology
  - travel
  - finance
  - entertainment
  - food
  - automotive
  - health

# Never show sponsorships from these categories
# Blocklist takes priority over allowlist
blocked_categories:
  - gambling
  - alcohol
  - tobacco
```

## How It Works

- Your preferences file stays on your machine — it is never stored by Overtone
- Preferences are sent with each news request and applied server-side as filters
- The blocklist always takes priority: if a category is in both lists, it's blocked
- If `allowed_categories` is empty or missing, all categories are allowed (except blocked ones)
- If the file doesn't exist, all sponsorship categories are allowed by default

## Available Categories

- `sports` — Athletic brands, equipment, events
- `technology` — Software, hardware, SaaS
- `travel` — Airlines, hotels, destinations
- `finance` — Banking, investment, fintech
- `entertainment` — Streaming, gaming, media
- `food` — Restaurants, delivery, CPG
- `automotive` — Cars, EVs, mobility
- `health` — Wellness, fitness, healthcare
- `fashion` — Apparel, luxury, retail
- `education` — Courses, platforms, institutions
