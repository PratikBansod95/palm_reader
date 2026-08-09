import 'dotenv/config';
import express from 'express';
import cors from 'cors';
import helmet from 'helmet';
import rateLimit from 'express-rate-limit';
import multer from 'multer';
import OpenAI from 'openai';
import sharp from 'sharp';

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

    const prompt = buildPrompt({ language, dominantHand });
    const prepared = await prepareImageForModel(image.buffer, detectedMimeType);

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
      temperature: 0.85,
      max_tokens: 900,
      messages: [
        {
          role: 'system',
          content:
            'You are an expert palmist and spiritual guide. Keep output warm, practical, and emotionally intelligent.',
        },
        {
          role: 'user',
          content: [
            { type: 'text', text: prompt },
            { type: 'image_url', image_url: { url: dataUrl } },
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
            text: 'You are an expert palmist and spiritual guide. Keep output warm, practical, and emotionally intelligent.',
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
            text: 'You are an expert palmist and spiritual guide. Keep output warm, practical, and emotionally intelligent.',
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

function buildPrompt({ language, dominantHand }) {
  return `Give a palmistry-style reading from this palm image. Use all the knowledge that's written available for Palmistry (preferred India knowledge) and try to be accurate.
Write as if speaking directly to the user in a natural, warm, intuitive voice.
User selected language: ${language}.
Dominant hand: ${dominantHand}.

Style requirements:
1) Write entirely in ${language}.
2) Sound human and fluid, like a thoughtful live reading, not an app report.
3) Keep it emotionally intelligent: supportive, honest, and gently mystical but grounded.
4) Use second-person voice ("you") and avoid repetitive phrasing.
5) Blend insights naturally across personality, life direction, love, money, challenge patterns, and practical next guidance.
6) Keep it specific enough to feel personal, but avoid extreme claims or guaranteed predictions.
7) If the image is unclear, briefly acknowledge uncertainty but still provide a best-effort reading.
8) Be scientific.

Formatting requirements:
1) Output plain text only.
2) No JSON, no markdown, no bullet points, no headings, no labels.
3) Write 4 to 6 short-to-medium paragraphs.

You must follow these strict rules:
1) Do NOT predict death, terminal illness, divorce certainty, exact dates of life events, or irreversible tragedies.
2) Do NOT make medical, legal, or financial guarantees.
3) If a user explicitly asks about death, disease, or harmful events, respond gently that such predictions are not ethical or scientifically valid, and encourage them to seek professional guidance instead.
4) Never create fear-based or manipulative responses.
5) Provide balanced insights: strengths, challenges, and constructive guidance.
6) If suggesting remedies, keep them symbolic, cultural, and non-harmful (e.g., mindfulness, positive affirmations, acts of kindness).
7) Tone should feel traditional, wise, calm, and respectful, but modern and responsible.
8) Even if user insists on asking extreme questions respond with: I cannot provide predictions about death or irreversible events. Palmistry is traditionally meant for self-reflection and personal growth, not for determining life-ending outcomes. Anyone claiming certainty about such matters is not being responsible or truthful. If you have concerns about your health or future, it's best to consult qualified professionals.`;
}

app.listen(port, () => {
  console.log(`Palm backend listening on port ${port} (provider=${configuredProvider})`);
});
