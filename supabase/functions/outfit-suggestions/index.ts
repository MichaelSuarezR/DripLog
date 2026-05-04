import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

type OutfitRow = {
  id: string
  image_path: string
  caption: string | null
  categories: string[] | null
  weather: string[] | null
  occasion: string[] | null
  colors: string[] | null
}

type InspirationRow = {
  id: string
  image_url: string
  caption: string | null
  categories: string[] | null
  weather: string[] | null
  occasion: string[] | null
  colors: string[] | null
  gender: string | null
}

type WeatherSnapshot = {
  location_name: string | null
  summary: string
  tags: string[]
  temperature_text: string
}

type ShortlistedOutfit = {
  id: string
  image_path: string
  tags: string[]
  categories: string[]
  weather: string[]
  occasion: string[]
  colors: string[]
}

type ShortlistedInspiration = {
  id: string
  image_url: string
  caption: string
  categories: string[]
  weather: string[]
  occasion: string[]
  colors: string[]
  gender: string
}

type OutfitWithImage = ShortlistedOutfit & {
  base64: string
  mimeType: string
}

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const supabaseUrl = Deno.env.get('SUPABASE_URL')
    const supabaseAnonKey = Deno.env.get('SUPABASE_ANON_KEY')
    const geminiApiKey = Deno.env.get('GEMINI_API_KEY')

    if (!supabaseUrl || !supabaseAnonKey || !geminiApiKey) {
      return json({ error: 'Missing required secrets.' }, 500)
    }

    const authHeader = req.headers.get('Authorization') ?? ''
    const supabase = createClient(supabaseUrl, supabaseAnonKey, {
      global: {
        headers: {
          Authorization: authHeader,
        },
      },
    })

    const body = await req.json()
    const userId = body.user_id as string
    const latitude = typeof body.latitude === 'number' ? body.latitude : null
    const longitude = typeof body.longitude === 'number' ? body.longitude : null
    const locality = typeof body.locality === 'string' && body.locality.trim().length > 0
      ? body.locality.trim()
      : null

    if (!userId) {
      return json({ error: 'Missing user_id.' }, 400)
    }

    if (latitude === null || longitude === null) {
      return json({ error: 'Missing device coordinates for live weather.' }, 400)
    }

    const [outfitsResult, inspirationResult] = await Promise.all([
      supabase
        .from('outfits')
        .select('id,image_path,caption,categories,weather,occasion,colors')
        .eq('user_id', userId)
        .order('created_at', { ascending: false }),
      supabase
        .from('inspiration_looks')
        .select('id,image_url,caption,categories,weather,occasion,colors,gender')
        .limit(120),
    ])

    if (outfitsResult.error) throw outfitsResult.error
    if (inspirationResult.error) throw inspirationResult.error

    const outfits = (outfitsResult.data ?? []) as OutfitRow[]
    const inspiration = (inspirationResult.data ?? []) as InspirationRow[]

    if (outfits.length === 0) {
      return json({ error: 'No outfits found for user.' }, 400)
    }

    if (inspiration.length === 0) {
      return json({ error: 'No inspiration looks available.' }, 400)
    }

    const weather = await fetchWeather(latitude, longitude, locality)
    const shortlist = buildShortlist(outfits, inspiration, weather.tags)
    const outfitsWithImages = await fetchOutfitImages(supabase, shortlist.outfits)

    if (outfitsWithImages.length < 1) {
      return json({ error: 'Could not load outfit images.' }, 500)
    }

    const aiResult = await buildSuggestionsWithGemini(
      outfitsWithImages,
      shortlist.inspiration,
      weather,
      geminiApiKey,
    )

    return json({
      left_outfit_id: aiResult.left_outfit_id,
      right_outfit_id: aiResult.right_outfit_id,
      inspiration: aiResult.inspiration,
      weather,
      explanation: aiResult.explanation,
    })
  } catch (error) {
    const message = error instanceof Error ? error.message : 'Unknown error'
    console.error('outfit-suggestions failed', error)
    return json({ error: message }, 500)
  }
})

function json(payload: unknown, status = 200) {
  return new Response(JSON.stringify(payload), {
    status,
    headers: {
      ...corsHeaders,
      'Content-Type': 'application/json',
    },
  })
}

function normalize(value: string) {
  return value.trim().toLowerCase()
}

function decodeCaptionTags(caption: string | null): string[] {
  if (!caption) return []
  try {
    const parsed = JSON.parse(caption)
    return Array.isArray(parsed) ? parsed.map((item) => String(item)) : []
  } catch {
    return []
  }
}

function outfitTokens(outfit: OutfitRow): string[] {
  return [
    ...decodeCaptionTags(outfit.caption),
    ...(outfit.categories ?? []),
    ...(outfit.weather ?? []),
    ...(outfit.occasion ?? []),
    ...(outfit.colors ?? []),
  ].map(normalize)
}

function inspirationTokens(look: InspirationRow): string[] {
  return [
    ...(look.categories ?? []),
    ...(look.weather ?? []),
    ...(look.occasion ?? []),
    ...(look.colors ?? []),
  ].map(normalize)
}

function score(tokens: string[], weatherTags: Set<string>, userVocabulary: Set<string>) {
  const tokenSet = new Set(tokens)
  let total = 0
  for (const tag of weatherTags) {
    if (tokenSet.has(tag)) total += 4
  }
  for (const token of tokenSet) {
    if (userVocabulary.has(token)) total += 1
  }
  return total + tokenSet.size
}

function buildShortlist(outfits: OutfitRow[], inspiration: InspirationRow[], weatherTags: string[]) {
  const normalizedWeather = new Set(weatherTags.map(normalize))
  const userVocabulary = new Set(outfits.flatMap(outfitTokens))

  const rankedOutfits = outfits
    .map((outfit) => ({
      outfit,
      score: score(outfitTokens(outfit), normalizedWeather, userVocabulary),
    }))
    .sort((a, b) => b.score - a.score)
    .slice(0, 6)
    .map(({ outfit }) => ({
      id: outfit.id,
      image_path: outfit.image_path,
      tags: decodeCaptionTags(outfit.caption),
      categories: outfit.categories ?? [],
      weather: outfit.weather ?? [],
      occasion: outfit.occasion ?? [],
      colors: outfit.colors ?? [],
    }))

  const rankedInspiration = inspiration
    .map((look) => ({
      look,
      score: score(inspirationTokens(look), normalizedWeather, userVocabulary),
    }))
    .sort((a, b) => b.score - a.score)
    .slice(0, 10)
    .map(({ look }) => ({
      id: look.id,
      image_url: look.image_url,
      caption: look.caption ?? '',
      categories: look.categories ?? [],
      weather: look.weather ?? [],
      occasion: look.occasion ?? [],
      colors: look.colors ?? [],
      gender: look.gender ?? 'unisex',
    }))

  return {
    outfits: diversifyOutfits(rankedOutfits),
    inspiration: diversifyInspiration(rankedInspiration),
  }
}

async function fetchOutfitImages(
  supabase: ReturnType<typeof createClient>,
  outfits: ShortlistedOutfit[],
): Promise<OutfitWithImage[]> {
  const results = await Promise.all(
    outfits.map(async (outfit) => {
      try {
        const { data, error } = await supabase.storage
          .from('outfit-photos')
          .download(outfit.image_path)

        if (error || !data) return null

        const arrayBuffer = await data.arrayBuffer()
        const base64 = uint8ToBase64(new Uint8Array(arrayBuffer))
        const mimeType = outfit.image_path.endsWith('.png') ? 'image/png' : 'image/jpeg'

        return { ...outfit, base64, mimeType }
      } catch {
        return null
      }
    }),
  )

  return results.filter((r): r is OutfitWithImage => r !== null)
}

function uint8ToBase64(bytes: Uint8Array): string {
  let binary = ''
  const chunkSize = 8192
  for (let i = 0; i < bytes.length; i += chunkSize) {
    binary += String.fromCharCode(...bytes.subarray(i, i + chunkSize))
  }
  return btoa(binary)
}

async function buildSuggestionsWithGemini(
  outfitsWithImages: OutfitWithImage[],
  inspirationShortlist: ShortlistedInspiration[],
  weather: WeatherSnapshot,
  apiKey: string,
) {
  const parts: unknown[] = []

  parts.push({
    text: [
      `You are a personal stylist AI for a fashion app.`,
      `You will see ${outfitsWithImages.length} outfit photo(s) from the user's wardrobe, each labeled with an ID and any metadata tags the user added.`,
      `Your tasks:`,
      `1. Pick the 2 best outfits for today's weather. If only 1 outfit is available, use it for both left and right.`,
      `2. Look carefully at each chosen photo and identify the specific clothing items you can see (e.g. "olive cargo pants", "white oversized tee", "chunky sneakers").`,
      `3. Pick the most relevant inspiration look from the text list provided.`,
      `4. Write a 2-3 sentence explanation that names specific items visible in the photos and explains why they work for today's conditions.`,
      ``,
      `Return a JSON object with exactly these fields:`,
      `- left_outfit_id: string (ID of first chosen outfit)`,
      `- right_outfit_id: string (ID of second chosen outfit, must differ from left if possible)`,
      `- inspiration_id: string (ID from the inspiration list)`,
      `- explanation: string (2-3 sentences referencing specific visible items)`,
    ].join('\n'),
  })

  for (const outfit of outfitsWithImages) {
    const allTags = [
      ...outfit.tags,
      ...outfit.categories,
      ...outfit.weather,
      ...outfit.occasion,
      ...outfit.colors,
    ].filter(Boolean)

    parts.push({
      text: `Outfit ID: ${outfit.id}\nUser tags: ${allTags.length > 0 ? allTags.join(', ') : 'none'}`,
    })
    parts.push({
      inlineData: {
        mimeType: outfit.mimeType,
        data: outfit.base64,
      },
    })
  }

  const weatherLine = [
    `Current weather: ${weather.tags.join(', ')} ${weather.temperature_text}`,
    weather.location_name ? `Location: ${weather.location_name}` : null,
  ].filter(Boolean).join('\n')

  const inspirationLines = inspirationShortlist.map((look) => {
    const tags = [...look.categories, ...look.weather, ...look.occasion, ...look.colors].filter(Boolean)
    return `ID: ${look.id} | ${tags.join(', ')}`
  }).join('\n')

  parts.push({
    text: `${weatherLine}\n\nInspiration look options — pick one by ID:\n${inspirationLines}`,
  })

  const response = await fetch(
    'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent',
    {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'x-goog-api-key': apiKey,
      },
      body: JSON.stringify({
        contents: [{ parts }],
        generationConfig: {
          temperature: 0.3,
          maxOutputTokens: 400,
          responseMimeType: 'application/json',
          responseSchema: {
            type: 'object',
            properties: {
              left_outfit_id: { type: 'string' },
              right_outfit_id: { type: 'string' },
              inspiration_id: { type: 'string' },
              explanation: { type: 'string' },
            },
            required: ['left_outfit_id', 'right_outfit_id', 'inspiration_id', 'explanation'],
          },
        },
      }),
    },
  )

  if (!response.ok) {
    const text = await response.text()
    console.error('Gemini error response', text)
    throw new Error(`Gemini request failed: ${text}`)
  }

  const responseJson = await response.json()
  const content = responseJson.candidates?.[0]?.content?.parts?.[0]?.text
  if (!content) {
    console.error('Gemini returned unexpected payload', responseJson)
    throw new Error('Gemini returned no content.')
  }

  const parsed = JSON.parse(content) as {
    left_outfit_id: string
    right_outfit_id: string
    inspiration_id: string
    explanation: string
  }

  const leftOutfit = outfitsWithImages.find((o) => o.id === parsed.left_outfit_id)
    ?? outfitsWithImages[0]

  const rightOutfit = outfitsWithImages.find((o) => o.id === parsed.right_outfit_id && o.id !== leftOutfit.id)
    ?? outfitsWithImages.find((o) => o.id !== leftOutfit.id)
    ?? leftOutfit

  const inspiration = inspirationShortlist.find((i) => i.id === parsed.inspiration_id)
    ?? inspirationShortlist[0]

  return {
    left_outfit_id: leftOutfit.id,
    right_outfit_id: rightOutfit.id,
    inspiration,
    explanation: parsed.explanation,
  }
}

async function fetchWeather(latitude: number, longitude: number, locality: string | null): Promise<WeatherSnapshot> {
  const url = new URL('https://api.open-meteo.com/v1/forecast')
  url.searchParams.set('latitude', String(latitude))
  url.searchParams.set('longitude', String(longitude))
  url.searchParams.set('current', 'temperature_2m,apparent_temperature,weather_code')
  url.searchParams.set('temperature_unit', 'fahrenheit')

  const response = await fetch(url)
  if (!response.ok) {
    throw new Error('Weather lookup failed.')
  }

  const data = await response.json()
  const current = data.current
  const apparent = Number(current.apparent_temperature ?? current.temperature_2m ?? 70)
  const code = Number(current.weather_code ?? 0)

  const tags: string[] = []
  let prefix = 'It is mild out,'

  if (apparent < 55) {
    tags.push('cold')
    prefix = 'It is cold out,'
  } else if (apparent < 70) {
    tags.push('cool')
    prefix = 'It is cool out,'
  } else if (apparent < 82) {
    tags.push('warm')
    prefix = 'It is warm out,'
  } else {
    tags.push('hot')
    prefix = 'It is hot out,'
  }

  if (code === 0) {
    tags.push('sunny')
  } else if ((code >= 51 && code <= 67) || (code >= 80 && code <= 86)) {
    tags.push('rainy')
  } else if (code >= 71 && code <= 77) {
    tags.push('snowy')
  } else {
    tags.push('cloudy')
  }

  return {
    location_name: locality,
    summary: `${prefix} ${tags[1] ?? 'clear'} conditions should drive the outfit choice${locality ? ` in ${locality}` : ''}.`,
    tags,
    temperature_text: `(${Math.round(apparent)}°F)`,
  }
}

function diversifyOutfits(outfits: ShortlistedOutfit[]) {
  if (outfits.length <= 2) return outfits
  const topBand = outfits.slice(0, Math.min(4, outfits.length))
  const remainder = outfits.slice(Math.min(4, outfits.length))
  return [...shuffle(topBand), ...remainder]
}

function diversifyInspiration(inspiration: ShortlistedInspiration[]) {
  if (inspiration.length <= 1) return inspiration
  const topBand = inspiration.slice(0, Math.min(5, inspiration.length))
  const remainder = inspiration.slice(Math.min(5, inspiration.length))
  return [...shuffle(topBand), ...remainder]
}

function shuffle<T>(items: T[]): T[] {
  const copy = [...items]
  for (let i = copy.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1))
    ;[copy[i], copy[j]] = [copy[j], copy[i]]
  }
  return copy
}
