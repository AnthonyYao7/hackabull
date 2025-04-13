import express from 'express';
import 'dotenv/config'
import {generateSession, generateFileId, extract_location_name} from "./util.js";
import fs from 'fs';
import axios from 'axios';

const computeRoutesURL = 'https://routes.googleapis.com/directions/v2:computeRoutes';

const app = express();
app.use(express.json());
app.use(express.urlencoded({ extended: true, limit: '10mb' }));
const port = 3000

app.get('/', async (req, res) => {
  res.send('hi');
})

var sessions = new Map();



app.post('/startSession', (req, res) => {
  const session = generateSession();
  sessions.set(session.sessionId, session)
  console.log('Created new session ' + JSON.stringify(session));
  res.send({sessionId: session.sessionId, token: session.token})
})

app.post('/setDestination', async (req, res) => {
  const body= req.body;
  const sessionId = body.sessionId;
  const token = body.token;
  if (sessions.get(sessionId).token !== token) {
    res.status(400);
    res.send({'message': 'invalid token'});
    return;
  }

  const audio = body.audioFile;
  const buffer = Buffer.from(audio, 'base64');
  const filename = `upload/${generateFileId('upload.mp3')}`;
  fs.writeFileSync(filename, buffer);

  console.log(`Filename: ${filename}`)
  const destination_name = await extract_location_name(filename);
  const session = sessions.get(sessionId);
  session.destination_name = destination_name;
  res.status(200)
  res.send({'message': `Destination set as ${destination_name}.`})
})

app.get('/destination', (req, res) => {
  const body= req.body;
  const sessionId = body.sessionId;
  const token = body.token;
  if (sessions.get(sessionId).token !== token) {
    res.status(400);
    res.send({'message': 'invalid token'});
    return;
  }

  res.send({'destination': sessions.get(sessionId).get('destination_name')});
})

app.get('/directions', async (req, res) => {
  const sessionId = req.query.sessionId;
  const token = req.query.token;
  if (sessions.get(sessionId).token !== token) {
    res.status(400);
    res.send({'message': 'invalid token'});
    return;
  }

  // TODO: get users coordinates
  const origin = {
    "location": {
      "latLng": {
        "latitude": 28.059656,
        // "latitude": req.query.lat,
        "longitude": -82.418612,
        // "longitude": req.query.lon
      }
    }
  }

  const destination = sessions.get(sessionId).destination_name;
  const query = {
    "origin": origin,
    "destination": {
      "address": destination
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