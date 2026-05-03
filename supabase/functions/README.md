# Supabase Edge Functions

## outfit-suggestions

Deploy this function after setting the required secrets:

```bash
supabase secrets set OPENAI_API_KEY=your_openai_api_key
supabase functions deploy outfit-suggestions
```

Required project secrets already available in Supabase functions runtime:
- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`

The function expects an authenticated request body shaped like:

```json
{
  "user_id": "uuid",
  "latitude": 34.0689,
  "longitude": -118.4452
}
```

It returns:

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
    "summary": "...",
    "tags": ["warm", "sunny"],
    "temperature_text": "(72°F)"
  },
  "explanation": "..."
}
```
