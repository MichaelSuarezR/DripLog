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
    const aiResult = await buildSuggestionsWithGemini(shortlist, weather, geminiApiKey)

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

  const json = await response.json()
  const current = json.current
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

async function buildSuggestionsWithGemini(
  shortlist: ReturnType<typeof buildShortlist>,
  weather: WeatherSnapshot,
  apiKey: string,
) {
  const leftOutfit = shortlist.outfits[0]
  const rightOutfit = pickSecondOutfit(shortlist.outfits, leftOutfit)
  const inspiration = shortlist.inspiration[0]

  if (!leftOutfit) {
    throw new Error('No shortlisted closet outfits were available.')
  }

  if (!inspiration) {
    throw new Error('No shortlisted inspiration looks were available.')
  }

  const prompt = [
    'You are writing a concise outfit suggestion explanation for a fashion app.',
    'Use the provided weather and the selected closet pieces.',
    'Mention concrete pieces from the left closet outfit and right closet outfit.',
    'Explain why the center inspiration look fits today.',
    'Return exactly 2 complete sentences in one paragraph.',
    'Sentence 1: explain why the inspiration look fits the current weather.',
    'Sentence 2: mention specific pieces from the left and right closet outfits that could be combined.',
    'Do not return sentence fragments.',
    '',
    JSON.stringify({
      weather,
      left_outfit: leftOutfit,
      right_outfit: rightOutfit,
      inspiration,
    }),
  ].join('\n')

  const response = await fetch('https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'x-goog-api-key': apiKey,
    },
    body: JSON.stringify({
      contents: [
        {
          parts: [
            {
              text: prompt,
            },
          ],
        },
      ],
      generationConfig: {
        temperature: 0.2,
        maxOutputTokens: 260,
      },
    }),
  })

  if (!response.ok) {
    const text = await response.text()
    console.error('Gemini error response', text)
    throw new Error(`Gemini request failed: ${text}`)
  }

  const json = await response.json()
  const content = json.candidates?.[0]?.content?.parts?.[0]?.text
  if (!content) {
    console.error('Gemini returned unexpected payload', json)
    throw new Error('Gemini returned no structured content.')
  }

  return {
    left_outfit_id: leftOutfit.id,
    right_outfit_id: rightOutfit.id,
    inspiration,
    explanation: buildExplanationText(content, weather, leftOutfit, rightOutfit, inspiration),
  }
}

function sanitizeExplanation(content: string) {
  return content
    .replace(/^```[\w-]*\s*/i, '')
    .replace(/\s*```$/, '')
    .replace(/\s+/g, ' ')
    .trim()
}

function diversifyOutfits(
  outfits: Array<{ id: string; image_path: string; tags: string[]; categories: string[]; weather: string[]; occasion: string[]; colors: string[] }>,
) {
  if (outfits.length <= 2) return outfits

  const topBand = outfits.slice(0, Math.min(4, outfits.length))
  const remainder = outfits.slice(Math.min(4, outfits.length))
  const shuffledTopBand = shuffle(topBand)
  return [...shuffledTopBand, ...remainder]
}

function diversifyInspiration(
  inspiration: Array<{ id: string; image_url: string; caption: string; categories: string[]; weather: string[]; occasion: string[]; colors: string[]; gender: string }>,
) {
  if (inspiration.length <= 1) return inspiration

  const topBand = inspiration.slice(0, Math.min(5, inspiration.length))
  const remainder = inspiration.slice(Math.min(5, inspiration.length))
  const shuffledTopBand = shuffle(topBand)
  return [...shuffledTopBand, ...remainder]
}

function shuffle<T>(items: T[]) {
  const copy = [...items]
  for (let index = copy.length - 1; index > 0; index -= 1) {
    const swapIndex = Math.floor(Math.random() * (index + 1))
    const current = copy[index]
    copy[index] = copy[swapIndex]
    copy[swapIndex] = current
  }
  return copy
}

function buildExplanationText(
  rawContent: string,
  weather: WeatherSnapshot,
  leftOutfit: { tags: string[]; categories: string[]; colors: string[] },
  rightOutfit: { tags: string[]; categories: string[]; colors: string[] },
  inspiration: { categories: string[]; colors: string[] },
) {
  const sanitized = sanitizeExplanation(rawContent)
  const wordCount = sanitized.split(/\s+/).filter(Boolean).length
  const sentenceCount = sanitized.split(/[.!?]+/).map((part) => part.trim()).filter(Boolean).length

  if (wordCount >= 18 && sentenceCount >= 2) {
    return sanitized
  }

  const leftPieces = preferredItems(leftOutfit.tags, leftOutfit.categories)
  const rightPieces = preferredItems(rightOutfit.tags, rightOutfit.categories)
  const inspirationPieces = preferredItems(inspiration.categories, inspiration.colors)

  return `${weather.summary} The inspiration look works because it lines up with today's conditions and leans on ${inspirationPieces}. You could pull ${leftPieces} from one closet outfit and ${rightPieces} from another to get close to that silhouette without starting from scratch.`
}

function preferredItems(primary: string[], secondary: string[]) {
  const items = [...primary, ...secondary]
    .map((value) => value.trim())
    .filter(Boolean)

  const unique: string[] = []
  for (const item of items) {
    if (!unique.some((existing) => normalize(existing) === normalize(item))) {
      unique.push(item)
    }
  }

  if (unique.length === 0) {
    return 'core pieces'
  }

  return unique.slice(0, 2).join(' and ')
}

function pickSecondOutfit(
  outfits: Array<{ id: string; tags: string[]; categories: string[]; weather: string[]; occasion: string[]; colors: string[] }>,
  leftOutfit: { id: string; tags: string[]; categories: string[]; weather: string[]; occasion: string[]; colors: string[] },
) {
  const leftTokens = new Set([
    ...leftOutfit.tags,
    ...leftOutfit.categories,
    ...leftOutfit.weather,
    ...leftOutfit.occasion,
    ...leftOutfit.colors,
  ].map(normalize))

  const candidates = outfits
    .slice(1)
    .map((outfit) => {
      const tokens = new Set([
        ...outfit.tags,
        ...outfit.categories,
        ...outfit.weather,
        ...outfit.occasion,
        ...outfit.colors,
      ].map(normalize))

      let overlap = 0
      for (const token of tokens) {
        if (leftTokens.has(token)) overlap += 1
      }

      return { outfit, overlap, tokenCount: tokens.size }
    })
    .sort((a, b) => {
      if (a.overlap == b.overlap) {
        return b.tokenCount - a.tokenCount
      }
      return a.overlap - b.overlap
    })

  return candidates[0]?.outfit ?? leftOutfit
}
