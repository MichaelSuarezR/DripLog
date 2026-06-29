# Supabase Edge Functions

This project currently ships two edge functions:

- `auto-tag-outfit`
- `outfit-suggestions`

Both functions use **Gemini** and require:

```bash
supabase secrets set GEMINI_API_KEY=your_gemini_api_key
```

`SUPABASE_URL` and `SUPABASE_ANON_KEY` are available in function runtime automatically.

---

## 1) `auto-tag-outfit`

### Purpose

Analyze an outfit photo and return normalized tags in four arrays:

- `categories`
- `weather`
- `occasion`
- `colors`

### Deploy

```bash
supabase functions deploy auto-tag-outfit
```

### Request

```json
{
  "image_base64": "<base64-encoded-jpeg>",
  "mime_type": "image/jpeg"
}
```

### Response

```json
{
  "categories": ["hoodie", "jeans"],
  "weather": ["cold"],
  "occasion": ["casual"],
  "colors": ["black", "blue"]
}
```

---

## 2) `outfit-suggestions`

### Purpose

Build a weather-aware outfit recommendation payload by combining:

- user closet outfits,
- inspiration look candidates,
- live weather context,
- Gemini ranking + explanation.

The function caches one suggestion per user per local date in `daily_outfit_suggestions`.

### Deploy

```bash
supabase functions deploy outfit-suggestions
```

### Request (authenticated)

```json
{
  "user_id": "uuid",
  "latitude": 34.0689,
  "longitude": -118.4452,
  "locality": "Los Angeles",
  "local_date": "2026-06-29"
}
```

`locality` and `local_date` are optional.

### Response

```json
{
  "left_outfit_id": "uuid",
  "right_outfit_id": "uuid",
  "inspiration": {
    "id": "uuid",
    "image_url": "https://...",
    "caption": "...",
    "categories": ["..."],
    "weather": ["..."],
    "occasion": ["..."],
    "colors": ["..."],
    "gender": "women"
  },
  "weather": {
    "location_name": "Los Angeles",
    "summary": "Clear sky",
    "tags": ["warm", "sunny"],
    "temperature_text": "(72°F)"
  },
  "explanation": "..."
}
```

---

## Local Development

```bash
supabase start
supabase db reset
supabase functions serve auto-tag-outfit
supabase functions serve outfit-suggestions
```

Deploy when ready:

```bash
supabase functions deploy auto-tag-outfit
supabase functions deploy outfit-suggestions
```
