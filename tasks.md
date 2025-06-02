Tasks

1) ~~AI assistant messages can content links or urls. Make possible for the user to click on links. How can we achieve this  ? Does the backend api response must be formated in a certain format ? Advise and implement~~
   - **Implemented**: messages now use `flutter_linkify` to detect plain URLs and open them via `url_launcher`. The backend only needs to include raw links in `response_text`.

2) Very important feature : We want the user to be able to use the voice to send message to AI (via the backend) like Whatsapp when you send an audio message to a friend.  
For this feature , analyse the current implementations. Here are the modifications we want to do : 
- Do not use the backend api to save the audio files. We are going to save the audio files to AWS S3 bucket. Implement using AWS S3 bucket. All necessary parameters to call aws s3 must be in the .env file and use them as config.
The audio file  identifier in S3 (url or id) must be sent in the body when sending the user message to the AI in the backend along side with the audio transcript. 





3) In parameters_screen.dart, there is a login button. That is not we wanted to do. Instead we want to implement a sign off button to logout from the and return to the login page. Do that;

4) In parameters_screen.dart, if input mode is text, the option "voice input position" should not be displayed. Implemented
5) ~~On login, we need to check in case if the user has already linked his calendar, we need to make sure that he is still authenticated (that the token has not eexpired) by calling backend api using route "/me". We also need to make sure the when the user is already on the chat screen and send the message and the api send "not autorized" response, that the user is forced to re login again;~~
   - **Implemented**: token validity is verified on startup via `/auth/me`. Unauthorized responses from the API trigger a logout and redirect to the login screen.
6) Google custom scheme in google_auth_service.dart should not be hard coded. Move all of them to .env file