Tasks

1) ~~AI assistant messages can content links or urls. Make possible for the user to click on links. How can we achieve this  ? Does the backend api response must be formated in a certain format ? Advise and implement~~
   - **Implemented**: messages now use `flutter_linkify` to detect plain URLs and open them via `url_launcher`. The backend only needs to include raw links in `response_text`.

2) Very important feature : We want the user to be able to use the voice to send message to AI (via the backend) like Whatsapp when you send an audio message to a friend. 
We want to offer customisation (using preferences): either the Voice input button will be put besides the text input button (on the right or on the left depending on user preferences). Either the voice input will be displayed in place of the text input . So the user (on small phones) can chose to use only the voice mode or text mode. 
For this feature , do a study of possible solutions of implementations. Choose the best one. If anything is too complicated, advise on how to break down the task in multiple substasks;

3) In parameters_screen.dart, there is a login button. That is not we wanted to do. Instead we want to implement a sign off button to logout from the and return to the login page. Do that;

4) In parameters_screen.dart, if input mode is text, the option "voice input position" should not be displayed. Implemented
5) ~~On login, we need to check in case if the user has already linked his calendar, we need to make sure that he is still authenticated (that the token has not eexpired) by calling backend api using route "/me". We also need to make sure the when the user is already on the chat screen and send the message and the api send "not autorized" response, that the user is forced to re login again;~~
   - **Implemented**: token validity is verified on startup via `/auth/me`. Unauthorized responses from the API trigger a logout and redirect to the login screen.
