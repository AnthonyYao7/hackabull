import express from 'express';
import 'dotenv/config'
import {generateSession, generateFileId, extract_location_name} from "./util.js";
import fs from 'fs';
import axios from 'axios';

const computeRoutesURL = 'https://routes.googleapis.com/directions/v2:computeRoutes';

const app = express();
app.use(express.json({limit: '10mb'}));
app.use(express.urlencoded({ extended: true, limit: '100mb' }));
const port = 3000

app.get('/', async (req, res) => {
  res.send('hi');
})


app.post('/directions', async (req, res) => {
  console.log(req.body)
  const audio = req.body.audio;
  const lat = req.body.latitude;
  const lon = req.body.longitude;
  const buffer = Buffer.from(audio, 'base64');
  const filename = `upload/${generateFileId('upload.m4a')}`;
  fs.writeFileSync(filename, buffer);

  console.log(`Filename: ${filename}`)
  const destination_name = await extract_location_name(filename);

  // TODO: get users coordinates
  const origin = {
    "location": {
      "latLng": {
        // "latitude": 28.059656,
        "latitude": lat,
        // "longitude": -82.418612,
        "longitude": lon
      }
    }
  }

  const query = {
    "origin": origin,
    "destination": {
      "address": destination_name
    },
    "travelMode": "WALK",
    "polylineQuality": "HIGH_QUALITY",
  };

  const headers = {
    'Content-Type': 'application/json',
    'X-Goog-Api-Key': process.env.GMAPS_API_KEY,
    'X-Goog-FieldMask': 'routes.polyline,routes.legs,routes.distanceMeters,routes.duration'
  };

  const response = await axios.post(computeRoutesURL, query, { headers: headers});
  res.send(response.data)
});

app.listen(port, () => {
  console.log('listening');
})