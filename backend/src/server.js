import 'dotenv/config';
import express from 'express';
import cors from 'cors';
import helmet from 'helmet';
import rateLimit from 'express-rate-limit';
import multer from 'multer';
import OpenAI from 'openai';
import sharp from 'sharp';
import crypto from 'crypto';

const app = express();

const port = Number(process.env.PORT || 8080);
const openAiModel = process.env.OPENAI_MODEL || 'gpt-4.1-nano';
const geminiModel = process.env.GEMINI_MODEL || 'gemini-2.0-flash';
const openRouterModel =
  process.env.OPENROUTER_MODEL || 'google/gemma-4-26b-a4b-it:free';
const openAiApiKey = (process.env.OPENAI_API_KEY || '').trim();
const geminiApiKey = (process.env.GEMINI_API_KEY || '').trim();
const openRouterApiKey = (process.env.OPENROUTER_API_KEY || '').trim();
const openRouterSiteUrl = (process.env.OPENROUTER_SITE_URL || 'https://github.com/PratikBansod95/palm_reader').trim();
const openRouterAppName = (process.env.OPENROUTER_APP_NAME || 'Palm Destiny').trim();
const appApiKey = (process.env.APP_API_KEY || '').trim();
const openAiTimeoutMs = Number(process.env.OPENAI_TIMEOUT_MS || 45000);
const allowedOrigins = String(process.env.CORS_ORIGIN || '')
  .split(',')
  .map((v) => v.trim())
  .filter(Boolean);
const trustProxy = process.env.TRUST_PROXY ?? (process.env.RENDER ? '1' : 'false');

const configuredProvider = resolveProvider();
if (!configuredProvider) {
  throw new Error(
    'Set OPENROUTER_API_KEY, GEMINI_API_KEY, or OPENAI_API_KEY. Optionally set AI_PROVIDER=openrouter|gemini|openai.',
  );
}

const openai = openAiApiKey ? new OpenAI({ apiKey: openAiApiKey }) : null;

if (trustProxy === 'true') {
  app.set('trust proxy', true);
} else if (trustProxy === 'false') {
  app.set('trust proxy', false);
} else {
  const proxyHops = Number.parseInt(trustProxy, 10);
  app.set('trust proxy', Number.isNaN(proxyHops) ? 1 : proxyHops);
}

const upload = multer({
  storage: multer.memoryStorage(),
  limits: {
    fileSize: 6 * 1024 * 1024,
    files: 1,
  },
});

app.use(helmet());
app.use(
  cors({
    origin: (origin, callback) => {
      if (!origin) {
        return callback(null, true);
      }
      if (allowedOrigins.length === 0) {
        // Local/dev friendly defaults when CORS_ORIGIN is unset.
        const localDefaults = [
          'http://localhost',
          'http://127.0.0.1',
          'http://localhost:3000',
          'http://localhost:5000',
          'http://localhost:8080',
          'http://localhost:5173',
        ];
        if (
          localDefaults.some((prefix) => origin.startsWith(prefix)) ||
          origin.startsWith('http://localhost:') ||
          origin.startsWith('http://127.0.0.1:')
        ) {
          return callback(null, true);
        }
        return callback(new Error('CORS blocked: CORS_ORIGIN is not configured'));
      }
      if (allowedOrigins.includes('*') || allowedOrigins.includes(origin)) {
        return callback(null, true);
      }
      return callback(new Error('CORS blocked: origin not allowed'));
    },
  }),
);
app.use(express.json({ limit: '1mb' }));

const defaultRateLimitPerMin = Number(process.env.RATE_LIMIT_PER_MIN || 120);
const palmRateLimitPerMin = Number(process.env.PALM_RATE_LIMIT_PER_MIN || 20);
const logPalmRequests = String(process.env.LOG_PALM_REQUESTS || 'true').toLowerCase() !== 'false';

app.use(
  '/api',
  rateLimit({
    windowMs: 60 * 1000,
    max: defaultRateLimitPerMin,
    standardHeaders: true,
    legacyHeaders: false,
  }),
);

const palmReadingLimiter = rateLimit({
  windowMs: 60 * 1000,
  max: palmRateLimitPerMin,
  standardHeaders: true,
  legacyHeaders: false,
  keyGenerator: (req) => getPalmClientKey(req),
  handler: (req, res) => {
    if (logPalmRequests) {
      console.warn(
        `[PalmRateLimit] local_rate_limit key="${getPalmClientKey(req)}" ip="${req.ip}" ua="${req.get('user-agent') || 'unknown'}"`,
      );
    }
    return res.status(429).json({ error: 'local_rate_limit' });
  },
});

app.get('/api/health', (_req, res) => {
  res.json({
    ok: true,
    provider: configuredProvider,
    model:
      configuredProvider === 'openrouter'
        ? openRouterModel
        : configuredProvider === 'gemini'
          ? geminiModel
          : openAiModel,
    openrouterConfigured: Boolean(openRouterApiKey),
    geminiConfigured: Boolean(geminiApiKey),
    openaiConfigured: Boolean(openAiApiKey),
  });
});

app.post('/api/palm-reading', palmReadingLimiter, upload.single('image'), async (req, res) => {
  try {
    if (logPalmRequests) {
      console.info(
        `[PalmRequest] start provider="${configuredProvider}" ip="${req.ip}" ua="${req.get('user-agent') || 'unknown'}" lang="${req.body?.language || 'English'}" hand="${req.body?.dominantHand || 'Right'}"`,
      );
    }

    if (appApiKey) {
      const incoming = String(req.headers['x-app-key'] || '');
      if (incoming !== appApiKey) {
        return res.status(401).json({ error: 'unauthorized' });
      }
    }

    const image = req.file;
    const language = (req.body.language || 'English').toString();
    const dominantHand = (req.body.dominantHand || 'Right').toString();

    if (!image) {
      return res.status(400).json({ error: 'image is required' });
    }

    const detectedMimeType = resolveImageMimeType(image);
    if (!detectedMimeType) {
      return res.status(400).json({ error: 'invalid image type' });
    }

    const prepared = await prepareImageForModel(image.buffer, detectedMimeType);
    const photoId = crypto
      .createHash('sha1')
      .update(prepared.base64.slice(0, 4000))
      .digest('hex')
      .slice(0, 8);
    const prompt = buildPrompt({ language, dominantHand, photoId });

    const reading = await withTimeout(
      runProvider({
        prompt,
        base64Image: prepared.base64,
        mimeType: prepared.mimeType,
      }),
      openAiTimeoutMs,
      'analysis request timed out',
    );

    if (!reading) {
      return res.status(502).json({ error: 'empty model output' });
    }

    if (logPalmRequests) {
      console.info('[PalmRequest] success');
    }

    return res.json({ reading });
  } catch (error) {
    if (error?.status === 429 || error?.code === 429) {
      console.error('[PalmRequest] upstream rate limited or quota exceeded');
      return res.status(503).json({ error: 'upstream_rate_limit' });
    }

    if (error?.message === 'analysis request timed out') {
      return res.status(504).json({ error: 'analysis timeout' });
    }

    console.error('[PalmRequest] failed', error?.message || error);
    const statusCode = error?.status || 500;
    if (statusCode >= 500) {
      return res.status(statusCode).json({ error: 'analysis failed' });
    }

    return res.status(statusCode).json({ error: 'request failed' });
  }
});

function resolveProvider() {
  const requested = String(process.env.AI_PROVIDER || '').trim().toLowerCase();
  if (requested === 'openrouter') {
    return openRouterApiKey ? 'openrouter' : null;
  }
  if (requested === 'gemini') {
    return geminiApiKey ? 'gemini' : null;
  }
  if (requested === 'openai') {
    return openAiApiKey ? 'openai' : null;
  }
  if (openRouterApiKey) {
    return 'openrouter';
  }
  if (geminiApiKey) {
    return 'gemini';
  }
  if (openAiApiKey) {
    return 'openai';
  }
  return null;
}

async function runProvider({ prompt, base64Image, mimeType }) {
  if (configuredProvider === 'openrouter') {
    return generateWithOpenRouter({ prompt, base64Image, mimeType });
  }
  if (configuredProvider === 'gemini') {
    return generateWithGemini({ prompt, base64Image, mimeType });
  }
  return generateWithOpenAI({ prompt, base64Image, mimeType });
}

async function prepareImageForModel(buffer, mimeType) {
  try {
    const optimized = await sharp(buffer)
      .rotate()
      .resize({
        width: 1280,
        height: 1280,
        fit: 'inside',
        withoutEnlargement: true,
      })
      .jpeg({ quality: 82, mozjpeg: true })
      .toBuffer();

    return {
      base64: optimized.toString('base64'),
      mimeType: 'image/jpeg',
    };
  } catch (error) {
    console.warn('[PalmRequest] image optimize failed, using original', error?.message || error);
    return {
      base64: buffer.toString('base64'),
      mimeType,
    };
  }
}

async function generateWithOpenRouter({ prompt, base64Image, mimeType }) {
  if (!openRouterApiKey) {
    const err = new Error('OpenRouter is not configured');
    err.status = 500;
    throw err;
  }

  const dataUrl = `data:${mimeType};base64,${base64Image}`;
  const response = await fetch('https://openrouter.ai/api/v1/chat/completions', {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${openRouterApiKey}`,
      'Content-Type': 'application/json',
      'HTTP-Referer': openRouterSiteUrl,
      'X-Title': openRouterAppName,
    },
    body: JSON.stringify({
      model: openRouterModel,
      temperature: 1.0,
      top_p: 0.95,
      max_tokens: 1200,
      seed: Math.floor(Math.random() * 1_000_000_000),
      messages: [
        {
          role: 'system',
          content:
            'You are a gifted Indian palmist and poetic spiritual guide. Your readings feel intimate, vivid, and emotionally intelligent - never generic. You ALWAYS look at the attached palm photo first. Anchor every claim to a visible feature in THIS photo. Never invent a reading when no clear hand is in the image. Never reuse the same opening, metaphors, or section wording across different photos. Always follow the exact labeled output format requested by the user.',
        },
        {
          role: 'user',
          content: [
            { type: 'image_url', image_url: { url: dataUrl } },
            { type: 'text', text: prompt },
          ],
        },
      ],
    }),
  });

  const payload = await response.json().catch(() => ({}));
  if (!response.ok) {
    const message =
      payload?.error?.message ||
      payload?.error ||
      `OpenRouter request failed (${response.status})`;
    const err = new Error(typeof message === 'string' ? message : 'OpenRouter request failed');
    err.status = response.status;
    err.code = response.status;
    throw err;
  }

  const content = payload?.choices?.[0]?.message?.content;
  if (typeof content === 'string') {
    return content.trim();
  }
  if (Array.isArray(content)) {
    return content
      .map((part) => (typeof part?.text === 'string' ? part.text : ''))
      .join('\n')
      .trim();
  }
  return '';
}

async function generateWithGemini({ prompt, base64Image, mimeType }) {
  const url = `https://generativelanguage.googleapis.com/v1beta/models/${encodeURIComponent(geminiModel)}:generateContent?key=${encodeURIComponent(geminiApiKey)}`;
  const response = await fetch(url, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      systemInstruction: {
        parts: [
          {
            text: 'You are a gifted Indian palmist and poetic spiritual guide. Your readings feel intimate, vivid, and emotionally intelligent - never generic. You ALWAYS look at the attached palm photo first. Anchor every claim to a visible feature in THIS photo. Never invent a reading when no clear hand is in the image. Never reuse the same opening across different photos. Always follow the exact labeled output format requested by the user.',
          },
        ],
      },
      contents: [
        {
          role: 'user',
          parts: [
            { text: prompt },
            {
              inlineData: {
                mimeType,
                data: base64Image,
              },
            },
          ],
        },
      ],
      generationConfig: {
        maxOutputTokens: 900,
        temperature: 0.85,
      },
    }),
  });

  const payload = await response.json().catch(() => ({}));
  if (!response.ok) {
    const err = new Error(payload?.error?.message || 'Gemini request failed');
    err.status = response.status;
    err.code = response.status;
    throw err;
  }

  const parts = payload?.candidates?.[0]?.content?.parts;
  if (!Array.isArray(parts)) {
    return '';
  }
  return parts
    .map((part) => (typeof part?.text === 'string' ? part.text : ''))
    .join('\n')
    .trim();
}

async function generateWithOpenAI({ prompt, base64Image, mimeType }) {
  if (!openai) {
    const err = new Error('OpenAI is not configured');
    err.status = 500;
    throw err;
  }

  const dataUrl = `data:${mimeType};base64,${base64Image}`;
  const response = await openai.responses.create({
    model: openAiModel,
    max_output_tokens: 900,
    input: [
      {
        role: 'system',
        content: [
          {
            type: 'input_text',
            text: 'You are a gifted Indian palmist and poetic spiritual guide. Your readings feel intimate, vivid, and emotionally intelligent - never generic. You ALWAYS look at the attached palm photo first. Anchor every claim to a visible feature in THIS photo. Never invent a reading when no clear hand is in the image. Never reuse the same opening across different photos. Always follow the exact labeled output format requested by the user.',
          },
        ],
      },
      {
        role: 'user',
        content: [
          { type: 'input_text', text: prompt },
          { type: 'input_image', image_url: dataUrl },
        ],
      },
    ],
  });

  return extractOutputText(response).trim();
}

function withTimeout(promise, timeoutMs, message) {
  return Promise.race([
    promise,
    new Promise((_, reject) => {
      setTimeout(() => reject(new Error(message)), timeoutMs);
    }),
  ]);
}

function getPalmClientKey(req) {
  return `${req.ip}:${req.get('user-agent') || 'unknown'}`;
}

function extractOutputText(response) {
  if (typeof response?.output_text === 'string' && response.output_text.trim()) {
    return response.output_text;
  }

  const output = response?.output;
  if (Array.isArray(output)) {
    for (const item of output) {
      if (!item || !Array.isArray(item.content)) continue;
      for (const contentItem of item.content) {
        if (contentItem?.type === 'output_text' && typeof contentItem.text === 'string' && contentItem.text.trim()) {
          return contentItem.text;
        }
      }
    }
  }

  return '';
}

function resolveImageMimeType(image) {
  if (image?.mimetype?.startsWith('image/')) {
    return image.mimetype;
  }
  const bytes = image?.buffer;
  if (!bytes || bytes.length < 12) {
    return null;
  }
  if (bytes[0] === 0xff && bytes[1] === 0xd8 && bytes[2] === 0xff) {
    return 'image/jpeg';
  }
  if (
    bytes[0] === 0x89 &&
    bytes[1] === 0x50 &&
    bytes[2] === 0x4e &&
    bytes[3] === 0x47 &&
    bytes[4] === 0x0d &&
    bytes[5] === 0x0a &&
    bytes[6] === 0x1a &&
    bytes[7] === 0x0a
  ) {
    return 'image/png';
  }
  if (
    bytes[0] === 0x52 &&
    bytes[1] === 0x49 &&
    bytes[2] === 0x46 &&
    bytes[3] === 0x46 &&
    bytes[8] === 0x57 &&
    bytes[9] === 0x45 &&
    bytes[10] === 0x42 &&
    bytes[11] === 0x50
  ) {
    return 'image/webp';
  }
  return null;
}

function buildPrompt({ language, dominantHand, photoId }) {
  return `You are giving a premium private palm reading. Study the palm image carefully and write a reading that feels personal, magnetic, and memorable - the kind of reading someone screenshots and sends to a friend saying "this is scary accurate."

Language: write the reading body entirely in ${language}.
User's usual dominant/writing hand (context only, not to be used to determine which hand appears in the photo): ${dominantHand}.
Photo id for this request (unique to this image): ${photoId}.
This reading must be unique to photo id ${photoId}. Do not reuse openings, metaphors, or section wording from any other reading.

IMAGE CHECK (mandatory, first step):
- If the image does not clearly show a human palm/hand, do not fabricate a reading. Output only:
  HAND: Unclear
  OPENING: One honest sentence explaining the photo doesn't show a clear hand, and inviting a retake.
  (stop after OPENING in this case)

HAND IDENTIFICATION (mandatory, when a hand is visible):
- Inspect thumb side, finger order, and palm orientation.
- Decide if the photo shows a LEFT or RIGHT hand.
- Never infer left/right from the form field. Name the hand only from the image.

HOW TO MAKE THIS FEEL REAL (mandatory technique):
- Look at THIS photo before writing. OPENING must name one concrete visible detail unique to this image (a specific line curve/break/branch, mount fullness, finger proportion, crease pattern, or texture).
- Anchor every claim to something visible: a specific line, its depth, length, branch, break, curve, or a mount's fullness, a finger's length relative to another, the hand's texture or temperature-look. Never make a claim you can't tie to a visible feature.
- Vary sentence length on purpose. Let some lines be short and land hard. Don't write four same-length sentences in a row.
- Use one concrete, unexpected image per section instead of abstract mood words. Not "you are creative" - instead, point to what that creativity actually looks like in their life (an unfinished project, a room rearranged at midnight, a habit of starting three things at once).
- Plant one detail in PERSONALITY or LIFE_PATH and pay it off later in GUIDANCE or BLESSING, so the reading feels like it's about one specific person, not a template.
- Write like you're noticing something in real time ("there - see how the line curves back toward the thumb"), not reciting a memorized meaning.

BANNED PATTERNS (these are the tells of a fake/generic reading - never use them):
- Generic openers: "Your hand tells a story," "The universe has written," "I see great things ahead," "Your palm carries a quiet radiance"
- Stock phrases: "old soul," "everything happens for a reason," "trust the journey," "your path is unique," "special gift," "destined for greatness"
- Vague hedge-everything statements that could apply to anyone
- Listing traits without tying them to a visible feature
- Ending every section on the same upbeat note - let CHALLENGES actually feel like a challenge before GUIDANCE resolves it
- Copy-paste sameness: if this reading could fit a different palm photo equally well, rewrite until it couldn't

READING QUALITY:
- Sound like a wise live reader speaking softly to one person, noticing details as they go.
- Warm, poetic, emotionally intelligent, grounded - never vague horoscope filler.
- Avoid fear, death predictions, medical/legal/financial guarantees, exact dates.
- Comment only on palmistry-relevant features (lines, mounts, shape, texture, finger proportions). Never remark on skin tone, scars, jewelry, or other personal appearance details.
- If the hand appears to belong to a minor, keep LOVE focused on friendship/family connection - never romantic or sexual framing.
- Give hope with honesty: real strengths, one honest soft challenge, and a genuinely useful next step - not just comfort.
- Target roughly 220-320 words total across all sections.

OUTPUT FORMAT (exact labels, in this order, each label on its own line, one blank line between sections):
HAND: Left or Right
OPENING: One magnetic sentence that hooks the heart - must include one concrete visible detail from THIS photo.
PERSONALITY: 2-4 sentences, anchored to a specific visible feature.
LIFE_PATH: 2-4 sentences, anchored to a specific visible feature.
LOVE: 2-4 sentences, anchored to a specific visible feature.
PROSPERITY: 2-4 sentences, anchored to a specific visible feature.
CHALLENGES: 2-3 sentences - name a real, specific soft challenge, don't soften it into nothing.
GUIDANCE: 2-4 sentences - resolve or pay off something planted earlier.
BLESSING: One short closing blessing line, specific to this person, not generic.

Rules:
- No markdown, no bullets, no extra labels, no preamble before HAND.
- Each section must feel distinct and vivid - no recycled phrasing, no recycled sentence structure across sections.
- If the image is unclear but a hand is visible, say so briefly in OPENING, then still give a best-effort reading.`;
}


app.listen(port, () => {
  console.log(`Palm backend listening on port ${port} (provider=${configuredProvider})`);
});
