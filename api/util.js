import crypto from 'crypto';
import {createPartFromUri, createUserContent, GoogleGenAI} from "@google/genai";
import { v4 as uuidv4 } from 'uuid';
const ai = new GoogleGenAI({ apiKey: process.env.GEMINI_API });


export function generateSession() {
  const sessionId = crypto.randomUUID();
  const token = crypto.randomBytes(32).toString('hex');
  const createdAt = new Date().toISOString();
  return {
    sessionId,
    token,
    createdAt
  };
}

export function generateFileId(filename) {
  const date = new Date().toISOString().replace(/[:.]/g, '-'); // e.g., 2025-04-12T18-32-45-123Z
  const uuid = uuidv4(); // random unique id
  const ext = filename.split('.').pop(); // keep original extension
  return `${date}_${uuid}.${ext}`;
}


export async function extract_location_name(filename) {
  console.log(`In filename: ${filename}`)
  const myfile = await ai.files.upload({
    file: filename,
    config: { mimeType: "audio/mp3" },
  });

  const response = await ai.models.generateContent({
    model: "gemini-2.0-flash",
    contents: createUserContent([
      createPartFromUri(myfile.uri, myfile.mimeType),
      "Transcribe this audio clip while looking for a location name. If there is extra language, such as 'Take me to ...' or 'I want to go to ...', get rid of it." +
      "Do not include any excess language. ",
    ]),
  });

  return response.text;
}
