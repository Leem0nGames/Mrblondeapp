import {genkit} from 'genkit';
import {googleAI} from '@genkit-ai/googleai';

const plugins = [];

if (process.env.GEMINI_API_KEY) {
  plugins.push(googleAI());
} else {
  // In a dev environment, it's useful to know if the key is missing.
  if (process.env.NODE_ENV === 'development') {
    console.warn(`
**************************************************************
* WARNING: GEMINI_API_KEY is not set.                        *
* AI-powered features will be disabled.                      *
* Please add GEMINI_API_KEY to your .env.local file.         *
**************************************************************
    `);
  }
}


export const ai = genkit({
  plugins: plugins,
});
