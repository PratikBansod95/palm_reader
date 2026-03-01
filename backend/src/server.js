import 'dotenv/config';
import express from 'express';
import cors from 'cors';
import helmet from 'helmet';
import rateLimit from 'express-rate-limit';
import multer from 'multer';
import OpenAI from 'openai';

const app = express();

const port = Number(process.env.PORT || 8080);
const corsOrigin = process.env.CORS_ORIGIN || '*';
const model = process.env.OPENAI_MODEL || 'gpt-4.1-mini';
const apiKey = process.env.OPENAI_API_KEY;

if (!apiKey) {
  throw new Error('OPENAI_API_KEY is required');
}

const openai = new OpenAI({ apiKey });

const upload = multer({
  storage: multer.memoryStorage(),
  limits: {
    fileSize: 6 * 1024 * 1024,
    files: 1,
  },
});

app.use(helmet());
app.use(cors({ origin: corsOrigin }));
app.use(express.json({ limit: '1mb' }));

app.use(
  rateLimit({
    windowMs: 60 * 1000,
    max: 30,
    standardHeaders: true,
    legacyHeaders: false,
  }),
);

app.get('/api/health', (_req, res) => {
  res.json({ ok: true });
});

app.post('/api/palm-reading', upload.single('image'), async (req, res) => {
  try {
    const image = req.file;
    const language = (req.body.language || 'English').toString();
    const dominantHand = (req.body.dominantHand || 'Right').toString();

    if (!image) {
      return res.status(400).json({ error: 'image is required' });
    }

    if (!image.mimetype?.startsWith('image/')) {
      return res.status(400).json({ error: 'invalid image type' });
    }

    const prompt = buildPrompt({ language, dominantHand });
    const base64Image = image.buffer.toString('base64');
    const dataUrl = `data:${image.mimetype};base64,${base64Image}`;

    const response = await openai.responses.create({
      model,
      max_output_tokens: 900,
      input: [
        {
          role: 'system',
          content: [
            {
              type: 'input_text',
              text:
                'You are an expert palmist and spiritual guide. Keep output warm, practical, and emotionally intelligent.',
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

    const reading = extractOutputText(response).trim();

    if (!reading) {
      return res.status(502).json({ error: 'empty model output' });
    }

    return res.json({ reading });
  } catch (error) {
    const statusCode = error?.status || 500;
    const message = statusCode >= 500 ? 'analysis failed' : String(error?.message || 'request failed');
    return res.status(statusCode).json({ error: message });
  }
});

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
  console.log(`Palm backend listening on port ${port}`);
});
