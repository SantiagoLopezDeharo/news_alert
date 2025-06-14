# News_alert

This repo shows a simple news alert system that can be self-hosted, for the tests I used a Galaxy S23 for the Front device and a Orange Pi zero 3 as Server.

## Tech Stack

| Golang | Firebase | Flutter | 
| ------ | ------ | ---------- |
| <img height="60" src="https://raw.githubusercontent.com/marwin1991/profile-technology-icons/refs/heads/main/icons/go.png"> | <img height="60" src="https://raw.githubusercontent.com/marwin1991/profile-technology-icons/refs/heads/main/icons/firebase.png"> | <img height="60" src="https://raw.githubusercontent.com/marwin1991/profile-technology-icons/refs/heads/main/icons/flutter.png"> |

## Arquitecture diagram

<img height="600" src="/news_alert.png">

## Setup

### FCM

For the push notifications and message system with firebase you will need to create a new app in the firebase console with the name `news alert` and enable FCM.

Within this dashboard in prject configuration you will need to generate a keys file.

You need two files, one for frontend and one for backend.

The private keys files, that will have a name similar to `news-alert-251e3-firebase-adminsdk-fbsvc-89b07f6e47.json` needs to be located at `backend/news-alert-firebase-.....`

Then, the `google-services.json` will have to be located at `news_alert/android/app/google-services.json`

### Compiling

`Make sure you have Golang version 1.23.0 or up`

For the Golang backend simply run the following command

```bash
cd backend && go build cmd/news_alert/main.go 
```
This will generate the binary, for starting the server simply execute it and it will start the server at port 8080:
```bash
./main
```

For the frnt simple use `flutter build apk` to generate an android package.

## Demo

[Watch the demo video](demo.mp4)
