import requests
import base64

def main():
    with open('../upload/sound.m4a', 'rb') as f:
        data = f.read()

    encoded = base64.b64encode(data).decode('utf-8')

#     session = requests.post('http://localhost:3000/startSession').json()
#     destination = requests.post('http://localhost:3000/setDestination', data={'sessionId': session.get('sessionId'), 'token': session.get('token'), 'audioFile': encoded})
#     print(destination.json())
    print(len(encoded))

    directions = requests.post('http://localhost:3000/directions',
        json={'audio': encoded, 'latitude': 28.059656, 'longitude': -82.418612})
    print(directions.json())


if __name__ == '__main__':
    main()
