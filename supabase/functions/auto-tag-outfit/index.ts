const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

const CATEGORIES = [
  // tops
  't-shirt', 'zip-up', 'tank top', 'crop top', 'button-up', 'hoodie', 'long-sleeve',
  'sweater', 'polo', 'cardigan', 'flannel', 'blouse',
  // bottoms
  'jeans', 'shorts', 'leggings', 'trousers', 'joggers', 'skirt', 'dress pants',
  'cargos', 'sweatpants', 'slacks', 'jorts', 'dress',
  // outerwear
  'coat', 'trench coat', 'jacket', 'fur coat', 'blazer', 'puffer jacket',
  'leather jacket', 'windbreaker', 'overcoat',
  // shoes
  'running shoes', 'boots', 'sandals', 'dress shoes', 'loafers', 'high heels', 'slides', 'sneakers',
  // accessories
  'hat', 'scarf', 'glasses', 'watch', 'handbag', 'necklace', 'earrings',
  'belt', 'bracelet', 'rings', 'gloves', 'sunglasses',
]

const WEATHER_OPTIONS = ['sunny', 'cold', 'rainy', 'snowy', 'humid', 'warm', 'hot', 'windy']
const OCCASION_OPTIONS = [
  'casual', 'formal', 'biz-casual', 'semi-formal', 'going out', 'outdoors',
  'date night', 'concert', 'at home', 'professional', 'beach', 'special event',
]
const COLOR_OPTIONS = [
  'black', 'white', 'gray', 'brown', 'blue', 'green',
  'red', 'pink', 'purple', 'yellow', 'orange', 'tan',
]

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const geminiApiKey = Deno.env.get('GEMINI_API_KEY')
    if (!geminiApiKey) {
      return json({ error: 'Missing GEMINI_API_KEY secret.' }, 500)
    }

    const body = await req.json()
    const imageBase64 = body.image_base64 as string | undefined
    const mimeType = (body.mime_type as string | undefined) ?? 'image/jpeg'

    if (!imageBase64) {
      return json({ error: 'Missing image_base64.' }, 400)
    }

    const result = await tagWithGemini(imageBase64, mimeType, geminiApiKey)
    return json(result)
  } catch (error) {
    const message = error instanceof Error ? error.message : 'Unknown error'
    console.error('auto-tag-outfit failed', error)
    return json({ error: message }, 500)
  }
})

function json(payload: unknown, status = 200) {
  return new Response(JSON.stringify(payload), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  })
}

async function tagWithGemini(
  imageBase64: string,
  mimeType: string,
  apiKey: string,
): Promise<{ categories: string[]; weather: string[]; occasion: string[]; colors: string[] }> {
  const prompt = [
    'You are a fashion tagging AI. Analyze the clothing items visible in this outfit photo.',
    'Return a JSON object with exactly these four keys: categories, weather, occasion, colors.',
    'Only use values from the lists below. Return empty arrays if uncertain.',
    '',
    `categories (clothing items visible): ${CATEGORIES.join(', ')}`,
    `weather (conditions this outfit suits): ${WEATHER_OPTIONS.join(', ')}`,
    `occasion (suitable occasions): ${OCCASION_OPTIONS.join(', ')}`,
    `colors (main clothing colors, not skin/hair/background): ${COLOR_OPTIONS.join(', ')}`,
    '',
    'Respond with only the JSON object, no other text.',
  ].join('\n')

  const response = await fetch(
    'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent',
    {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'x-goog-api-key': apiKey,
      },
      body: JSON.stringify({
        contents: [{
          parts: [
            { text: prompt },
            { inlineData: { mimeType, data: imageBase64 } },
          ],
        }],
        generationConfig: {
          temperature: 0.1,
          maxOutputTokens: 1024,
          responseMimeType: 'application/json',
        },
      }),
    },
  )

  if (!response.ok) {
    const text = await response.text()
    console.error('Gemini error', text)
    throw new Error(`Gemini request failed: ${text}`)
  }

  const data = await response.json()
  const content = data.candidates?.[0]?.content?.parts?.[0]?.text
  if (!content) {
    throw new Error('Gemini returned no content.')
  }

  const parsed = JSON.parse(content)

  const categorySet = new Set(CATEGORIES)
  const weatherSet = new Set(WEATHER_OPTIONS)
  const occasionSet = new Set(OCCASION_OPTIONS)
  const colorSet = new Set(COLOR_OPTIONS)

  return {
    categories: (parsed.categories ?? []).filter((v: string) => categorySet.has(v)),
    weather:    (parsed.weather    ?? []).filter((v: string) => weatherSet.has(v)),
    occasion:   (parsed.occasion   ?? []).filter((v: string) => occasionSet.has(v)),
    colors:     (parsed.colors     ?? []).filter((v: string) => colorSet.has(v)),
  }
}
