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

7) Add language preferences in the parameters screen

8) Very important feature : We want the user to be able to use the voice to send message to AI (via the backend) like Whatsapp when you send an audio message to a friend.

**Analysis completed**: The voice recording and transcription work correctly. Issues identified:
- AWS S3 upload was failing due to missing session token support for temporary credentials
- Backend integration exists but needs verification that audio URLs are preserved in conversation history

**Subtasks**:

8.1) Fix AWS S3 upload issues (COMPLETED)
   - Added AWS_SESSION_TOKEN support for temporary credentials
   - Fixed S3 status code checking (now accepts 200 and 201)
   - Added required headers (Content-Length, x-amz-security-token)
   - Improved error handling and user feedback
   - **Action required**: Add AWS_SESSION_TOKEN to .env file

8.2) Verify backend conversation storage
   - Confirm backend stores audio URLs in conversation history
   - Ensure backend returns audio URLs in the expected format:
     ```json
     {
       "transcript": "user's spoken text",
       "audio_url": "https://s3.../audio.m4a"
     }
     ```
   - Test that audio URLs are preserved when loading previous conversations

8.3) Implement audio playback UI
   - Add audio player widget to ChatMessageBubble
   - Support play/pause functionality
   - Show playback progress
   - Handle loading states and errors
   - Cache audio files locally for better performance
   - Support background audio playback

8.4) Enhanced audio message features
   - Add waveform visualization during recording
   - Show recording duration in real-time
   - Allow users to preview/re-record before sending
   - Add option to send audio without transcription
   - Implement audio message deletion from S3

8.5) Testing and polish
   - Test with various audio lengths
   - Handle network errors gracefully
   - Test audio playback across app lifecycle
   - Ensure proper cleanup of temporary files
   - Add loading indicators for audio messages  

9) Write a documentation to describe in details how the "preference_service.dart" component interacts with the backend api using the preferences endpoint "${AppConfig.backendApiBaseUrl}/preferences/$userId" . Describe api data input and output data models and how they are used. 

10) We need to make sure that if the user is not authenticated and he is trying to update its preferences, that he is loggout from the application

11) We need a proper check of cache state in order to wipe out the cache to avoid inconsistent data when necessary

12) Handle secret in .env files very well
 
13) Implement all preferences settings in the screen very well even with default values if necessary -> Needs a way to tell the user to manage its preferences for the AI to work efficiently

14) Verify voice to text implementation in file "chat_screen.dart". There is a bug when calling the following three lines  at line 109,
'''
    await _recorder.startRecording();
    final text = await _speechService.listenOnce();
    final recordedPath = await _recorder.stopRecording();
'''
After debugging it seems that "final text = await _speechService.listenOnce();" is not doing anything . Sometimes the mobile freezes totally on that line. Or sometimes it just returns null. I am not sure it is the thing to do to call "speechService.listenOnce()". 
The idea would be better with wait for the recording to end before getting the transcript. But stream implementation of voice recording and transcript can of course bring more performance. Choose wisely what to do here by analysing the "speech_service.dart" file

