Orion Flutter Frontend Architecture and Roadmap (Reviewed)
Architecture Design
Components (UI & Logic): Organize the app by feature for modularity using Flutter packages or a clear directory structure. Key UI components (Widgets/Screens) include:
LoginScreen: Handles user authentication via Google Sign-In. Presents UI elements for sign-in and manages the flow via AuthenticationService.
ChatScreen: Provides the conversational UI. Displays a scrollable list of messages (ChatMessageBubble widgets) and includes an input field (MessageInputBar). Interacts with ChatService to send user prompts to the backend orchestrator and display responses.
EventListScreen: Displays a list/calendar view of the user's upcoming events (CalendarEventTile widgets). Fetches event data via CalendarService.
PreferencesScreen: Allows users to view and modify settings (e.g., notification preferences, default view). Interacts with PreferenceService (or CacheService).
Shared/UI Widgets: Reusable Flutter widgets like ChatMessageBubble, MessageInputBar, LoadingIndicator, CalendarEventTile, ErrorDisplayWidget.
Logical/service modules (non-UI, typically Dart classes/singletons managed via dependency injection or providers) include:
AuthenticationService: Wraps google_sign_in and firebase_auth. Handles Google login flow, obtains Firebase credentials, manages user session state (current user, ID token). Exposes methods like signInWithGoogle(), signOut(), and a stream/notifier for the current User object and potentially the Google OAuth accessToken if needed for direct calendar reads.
PreferenceService: [Reviewer Note: Added explicit service] Manages user-specific settings. Provides methods like getPreferences() and savePreferences(prefs). Uses CacheService for persistence. Separates preference logic from general caching.
CalendarService: Encapsulates interactions for reading calendar data.
Strategy Decision: [Reviewer Note: Clarified strategy choice] Primarily focuses on fetching/reading events. Option A (Direct Read): Uses Google Calendar API directly via googleapis package or HTTP calls, authorized with the OAuth accessToken from AuthenticationService. Option B (Backend Proxy): Calls a dedicated Orion backend endpoint to read events. (Start with Option A for reads, assuming appropriate scopes requested during login).
Methods: Future<List<CalendarEvent>> fetchEvents(DateRange range). Handles authorization, API calls, error handling, and parsing JSON into CalendarEvent models.
Note: Event creation/modification/deletion initiated via chat must go through the ChatService to the backend orchestrator, not directly via this service. Direct modification from a calendar UI element could be a separate feature using this service's potential future create/update/delete methods, but that's distinct from the AI flow.
ChatService: [Reviewer Note: Corrected responsibility] Interfaces only with the Orion backend orchestration API (/v1/chat/prompt).
Method: Future<ChatResponseData> sendMessage(ChatRequestData requestData). Handles making the authenticated HTTP POST request to the backend, sending user prompt/session/context, and receiving the structured ChatResponseData (indicating completion, clarification needed, or error). Does not interact directly with any LLM API.
VoiceService: Interfaces with device speech recognition (e.g., using Flutter's speech_to_text package). Methods: startListening(), stopListening(), onResult(callback), onError(callback), hasPermission(), requestPermission(). Handles platform specifics and permissions.
NotificationService: Manages push (via FCM using firebase_messaging) and local notifications (using flutter_local_notifications). Methods: requestPermissions(), getToken() (FCM), scheduleLocalNotification(event, timeBefore), handleIncomingPushMessage(message), showNotification(). Abstracts platform differences.
CacheService (Local Storage): Provides low-level local persistence using Hive, shared_preferences, or SQLite (sqflite). Methods: saveObject(key, value), getObject(key), saveList(key, list), getList(key). Handles serialization/deserialization. Used by PreferenceService, CalendarService (for caching events), ChatManager (for caching history).
ConnectivityService: [Reviewer Note: Added explicit service] Wraps the connectivity_plus package. Provides a stream or notifier for the current network status (bool isConnected).
SyncService: [Reviewer Note: Clarified role] Primarily focuses on detecting when to potentially trigger actions upon reconnection. Complex offline queueing/syncing is deferred post-MVP unless critical. Monitors network state via ConnectivityService. Methods: onConnectivityChange(bool isOnline) which might trigger checks or UI updates. (Heavy background sync is complex; MVP focuses on offline viewing).
ChatManager: [Reviewer Note: Refocused responsibility] Primarily manages the local chat state (message list, session ID) and orchestrates UI updates based on ChatService responses.
Maintains the list/stream of ChatMessage objects for the UI.
Receives user input (text/voice transcript) and calls ChatService.sendMessage.
Processes the ChatResponseData from ChatService: updates message list with assistant response, handles clarification prompts, displays errors.
Does not directly call LLMService or CalendarService. It relies on the backend orchestrator (via ChatService) to handle intents and tool calls.
State Management: [Reviewer Note: Added section] Utilize a state management solution like Provider, Riverpod, or Bloc. Define providers/blocs for managing global state (Auth state, Preferences, Connectivity) and screen-level state (Chat messages, Event list, Loading/Error states). Services will typically be injected or accessed via these providers/blocs.
Component Interfaces and Communication Flow (Revised):
User Input (Voice/Text): User interacts via ChatScreen's MessageInputBar. Tapping mic invokes VoiceService. Typing updates text input state.
Send Message: User taps Send or VoiceService returns transcript. ChatScreen calls ChatManager.sendUserMessage(text).
ChatManager (Local Update): ChatManager adds a ChatMessage(sender='user', text=...) to its local state/stream immediately. UI updates.
Backend Request: ChatManager prepares ChatRequestData (including sessionId, userId from AuthService) and calls ChatService.sendMessage(requestData). UI shows loading state (e.g., assistant "typing" bubble).
ChatService: Gets Firebase ID token, sends authenticated POST to backend /v1/chat/prompt.
Backend Orchestration: (Handled by backend as planned previously) Backend receives request, calls Gemini, handles potential function calls (e.g., to its internal Calendar client/scheduler logic), gets final response from Gemini.
Backend Response: Backend sends ChatResponseData back to the frontend ChatService.
ChatService: Receives response, parses it, returns ChatResponseData to ChatManager. Handles network/HTTP errors.
ChatManager (Process Response): ChatManager receives ChatResponseData.
If status == 'completed', adds ChatMessage(sender='assistant', text=response_text) to state/stream.
If status == 'needs_clarification', adds assistant message with the question (response_text) and potentially makes clarification_options available to the UI.
If status == 'error', adds an error message (ChatMessage(sender='assistant', text=error_message, type='error')).
UI Update: ChatScreen (listening to ChatManager's state/stream) updates the message list, removing the loading indicator.
(Separate Flow) Event Viewing: EventListScreen (on load/refresh) calls CalendarService.fetchEvents(). CalendarService (using Option A) gets Google accessToken from AuthService, calls Google Calendar API, parses results, returns List<CalendarEvent>. EventListScreen displays the list. If offline (checked via ConnectivityService), it attempts to load from CacheService.
Data Structures:
UserProfile & Preferences: (Structure seems reasonable)
// Example Dart class
class UserProfile {
  final String userId;
  final String? email;
  final String? name;
  String timeZone; // IANA timezone
  String defaultCalendarId; // e.g. 'primary'
  String language; // e.g. 'en'
  bool notificationsEnabled;
  bool voiceEnabled;
  // Constructor, fromJson, toJson methods...
}


CalendarEvent: (Structure aligns with Google API, use DateTime for dates)
// Example Dart class
class CalendarEvent {
  final String id;
  final String? summary; // Title
  final String? description;
  final String? location;
  final EventDateTime start;
  final EventDateTime end;
  final List<EventAttendee>? attendees;
  // Constructor, fromJson (parsing Google API response)
}

class EventDateTime {
  final DateTime? dateTime; // Use if time is specified
  final DateTime? date;     // Use if all-day event (store as date only)
  final String? timeZone;
  // Constructor, fromJson
}

class EventAttendee {
  final String? email;
  // Constructor, fromJson
}


ChatMessage: (Structure seems reasonable)
// Example Dart class
enum MessageSender { user, assistant }
enum MessageStatus { sending, sent, error } // Added status

class ChatMessage {
  final String id; // Use uuid package
  final MessageSender sender;
  final String text;
  final DateTime timestamp;
  final MessageStatus? status; // For UI feedback
  // Constructor
}


Backend Communication Data Transfer Objects (DTOs): [Reviewer Note: Renamed from LLMResponse for clarity] Define Dart classes matching the JSON schemas for ChatRequestData and ChatResponseData used by ChatService to communicate with the backend API.
// Example Dart class for backend response
enum BackendResponseStatus { completed, needs_clarification, error }

class ChatResponseData {
  final String sessionId;
  final BackendResponseStatus status;
  final String? responseText;
  final List<String>? clarificationOptions;
  // Constructor, fromJson
}
// Define ChatRequestData similarly


Data Flow Example (Scheduling Event - Revised):
User speaks/types: "Schedule meeting..."
VoiceService (if used) -> Text transcript.
ChatScreen -> ChatManager.sendUserMessage(text).
ChatManager adds User ChatMessage to local state/stream. UI updates.
ChatManager calls ChatService.sendMessage({ userId, prompt: text, sessionId }). UI shows loading.
ChatService gets token, sends POST /v1/chat/prompt to Orion Backend.
Backend handles LLM interaction, intent detection ("create-calendar-event"), parameter extraction, calls its internal Calendar client/scheduler logic, creates event via Google API.
Backend sends ChatResponseData (e.g., { status: 'completed', response_text: 'OK, scheduled...' }) back.
ChatService receives response, returns ChatResponseData to ChatManager.
ChatManager receives ChatResponseData, adds Assistant ChatMessage ("OK, scheduled...") to local state/stream. UI updates (replaces loading bubble).
(Separately) CalendarService might fetch events later, or the backend could potentially push an update (more complex), showing the new event in the EventListScreen. Caching helps bridge this.
Error Handling Strategies (Refined):
Network/API Failures: ChatService and CalendarService implement try/catch and potentially retry logic (FE-TASK-17). Failed retries result in specific errors thrown (e.g., NetworkError, ApiError(statusCode)). ChatManager or UI layer catches these.
Authentication Errors: AuthenticationService handles token refresh failures. If sign-in needed, UI navigates to LoginScreen. If an API call (e.g., CalendarService.fetchEvents) gets 401/403, it should ideally trigger AuthenticationService.signOut() or prompt re-login.
Backend Orchestrator Errors: The backend /v1/chat/prompt endpoint should return structured errors (e.g., { status: 'error', response_text: 'Sorry, I couldn't reach the calendar.' }). ChatManager displays response_text as an assistant error message.
Voice Recognition Errors: VoiceService provides error callbacks. ChatScreen displays feedback ("Couldn't hear you", "Mic permission needed").
Cache Errors: CacheService methods use try/catch. Log errors, but generally allow the app to continue without caching if writes fail. Handle load failures gracefully (e.g., return empty list).
UI Feedback: Consistent use of loading indicators (CircularProgressIndicator), error messages (Snackbars via ScaffoldMessenger, inline text, or dedicated error bubbles in chat), and retry options.
UX Strategy (Refined):
Loading/Latency: Use CircularProgressIndicator for screen loads, Shimmer effect for list placeholders, animated "typing" indicator in chat.
Error Feedback: Use ScaffoldMessenger.showSnackBar for transient errors (network, save failed) with optional "Retry" action. Display persistent errors inline (e.g., "Couldn't load events" in EventListScreen, error bubble in ChatScreen).
Onboarding: Streamline: 1. Welcome/Explain. 2. Google Sign-In. 3. Permission Requests (Mic, Notifications) with clear rationale. Store completion flag via PreferenceService.
Offline Behavior: Focus on offline viewing. Use ConnectivityService.
EventListScreen: Loads from CacheService if offline, shows banner. Disable refresh.
ChatScreen: Disable input/send button if offline, show banner. Display cached history via CacheService.
PreferencesScreen: Always loads/saves locally via PreferenceService/CacheService.
Consistency: Use Material 3 design principles (material_color_utilities, ThemeData). Ensure accessible touch targets and contrasts.
Implementation Roadmap (Scrum-Style Tasks - Revised)
[Reviewer Note: Added explicit dependencies, refined steps, added State Management task]
FE-TASK-1: Project Initialization & Core Dependencies
Name/Description: Scaffold a new Flutter project for mobile and web, adding essential dependencies.
Input: Flutter SDK installed.
Expected Output: Runnable Flutter project (lib/main.dart) with pubspec.yaml including core packages. Basic lib/src structure.
Steps:
1.1: Run flutter create orion_app --platforms=android,ios,web.
1.2: Create lib/src and subdirectories (auth, chat, core, events, navigation, preferences, services, ui, utils).
1.3: Add core dependencies to pubspec.yaml: flutter_bloc / provider / riverpod (choose one), google_sign_in, firebase_core, firebase_auth, firebase_analytics, firebase_messaging (optional for now), http, connectivity_plus, speech_to_text (optional for now), uuid, intl, equatable (if using Bloc/models), googleapis (optional, if direct read), hive/hive_flutter or sqflite, path_provider, flutter_local_notifications (optional for now).
1.4: Run flutter pub get.
1.5: Set up basic main.dart initializing Flutter binding.
1.6: Initialize Git repository and commit.
Depends on: None.
Next Task: FE-TASK-2, FE-TASK-3.
FE-TASK-2: Firebase Project Setup & Integration (Native)
Name/Description: Configure Firebase for Android, iOS, and Web within the Flutter project.
Input: Firebase project created; Flutter project (FE-TASK-1).
Expected Output: firebase_core initialized successfully on all platforms. Test analytics event logged.
Steps:
2.1: Follow firebase_core setup: Add Android/iOS apps in Firebase console, download google-services.json / GoogleService-Info.plist.
2.2: Place config files in correct locations (android/app/, ios/Runner/). Add to Xcode project.
2.3: Configure native projects: Add Google Services plugin to Android Gradle files. Add Firebase init code to AppDelegate.
2.4: Configure Firebase for Web: Add Firebase config object (apiKey, authDomain, etc.) to web/index.html or initialize via Dart.
2.5: Initialize Firebase in main.dart: await Firebase.initializeApp(...).
2.6: Add test analytics.logEvent('app_configured') call.
2.7: Verify Android package name/SHA-1s and iOS Bundle ID match Firebase settings.
Depends on: FE-TASK-1.
Next Task: FE-TASK-3.
FE-TASK-3: Google Sign-In Configuration
Name/Description: Configure the google_sign_in plugin for all platforms.
Input: Firebase configured (FE-TASK-2), OAuth Client IDs from Google Cloud Console (Web, Android, iOS).
Expected Output: google_sign_in plugin ready for use.
Steps:
3.1: Ensure OAuth Client IDs are created in Google Cloud Console for Android, iOS, and Web, associated with the Firebase project.
3.2: Follow google_sign_in setup instructions for Android (SHA1 keys already added in FE-TASK-2).
3.3: Follow google_sign_in setup for iOS (URL Schemes in Info.plist).
3.4: For Web, the Client ID might be configured during Firebase web setup or passed to GoogleSignIn constructor if needed.
3.5: Verify setup by attempting a basic GoogleSignIn().signInSilently() call (it will likely fail without user interaction, but shouldn't crash if configured).
Depends on: FE-TASK-2.
Next Task: FE-TASK-4.
FE-TASK-4: Implement AuthenticationService & State
Name/Description: Implement the AuthenticationService class and set up global auth state management.
Input: Configured firebase_auth, google_sign_in. Chosen state management package (Provider/Riverpod/Bloc).
Expected Output: AuthenticationService with signInWithGoogle, signOut methods. Global state exposing User? and loading/error status.
Steps:
4.1: Create src/auth/auth_service.dart. Implement the class.
4.2: Implement signInWithGoogle(): Calls GoogleSignIn.signIn(), gets idToken/accessToken, creates GoogleAuthProvider.credential, calls FirebaseAuth.instance.signInWithCredential. Handles errors.
4.3: Implement signOut(): Calls FirebaseAuth.instance.signOut(), GoogleSignIn.signOut().
4.4: Set up state management: Create an AuthBloc/AuthProvider/AuthNotifier.
4.5: Use FirebaseAuth.instance.authStateChanges().listen(...) within the provider/bloc to listen for auth state and update the global state (User?, isLoading, error).
4.6: Expose service methods and state via the chosen state management solution.
Depends on: FE-TASK-1 (State Mgt Choice), FE-TASK-3.
Next Task: FE-TASK-5.
FE-TASK-5: Implement LoginScreen UI & Logic
Name/Description: Build the Login screen UI and connect it to the AuthenticationService.
Input: AuthenticationService state/methods available via state management.
Expected Output: A functional LoginScreen widget triggering sign-in and reacting to loading/error states.
Steps:
5.1: Create src/auth/login_screen.dart.
5.2: Build the UI (Logo, Title, Google Sign-In Button widget).
5.3: Use the state management solution to access signInWithGoogle method and isLoading/error state from AuthenticationService.
5.4: Connect button's onPressed to call signInWithGoogle.
5.5: Display CircularProgressIndicator when isLoading is true.
5.6: Display error messages (e.g., using ScaffoldMessenger) when error state is not null.
Depends on: FE-TASK-4.
Next Task: FE-TASK-6.
FE-TASK-6: Implement Basic Navigation Structure
Name/Description: Set up MaterialApp, NavigationContainer (if needed, often implicit with GoRouter or top-level MaterialApp), and basic navigators (Auth, Main Tabs). Implement routing based on auth state.
Input: State management providing auth state (User?). Placeholder screen widgets. Navigation package (go_router recommended for Flutter).
Expected Output: App navigates to Login screen when logged out, and Main Tabs screen when logged in.
Steps:
6.1: Choose navigation package (e.g., go_router). Add to pubspec.yaml.
6.2: Configure MaterialApp.router (if using GoRouter) or standard MaterialApp with Navigator widgets.
6.3: Define routes (e.g., /login, /chat, /events, /prefs).
6.4: Create MainTabsScreen widget containing BottomNavigationBar and logic to switch between placeholder ChatScreen, EventListScreen, PreferencesScreen widgets.
6.5: Implement redirect logic based on auth state (e.g., using GoRouter's redirect or listening to auth state in main.dart). If not logged in, redirect to /login. If logged in, redirect to /chat (or initial tab).
6.6: Ensure LoginScreen is displayed correctly via its route.
Depends on: FE-TASK-4, FE-TASK-5. Placeholder screens.
Next Task: FE-TASK-7 (Chat UI).
FE-TASK-7: Implement ChatScreen UI
Name/Description: Build the visual layout for ChatScreen, including message list and input bar components.
Input: Flutter UI knowledge.
Expected Output: ChatScreen widget displaying a list of ChatMessageBubble widgets and a MessageInputBar widget. Placeholder data used.
Steps:
7.1: Create src/chat/chat_screen.dart.
7.2: Create src/ui/widgets/chat_message_bubble.dart. Implement bubble styling based on sender.
7.3: Create src/ui/widgets/message_input_bar.dart. Include TextField and send IconButton.
7.4: In ChatScreen, use Scaffold, ListView.builder (or CustomScrollView with SliverList) for messages (set reverse: true). Use Column containing the list and the input bar.
7.5: Ensure input bar stays fixed at the bottom and adjusts for keyboard (Scaffold.resizeToAvoidBottomInset: true).
7.6: Add basic TextEditingController for the input field.
Depends on: FE-TASK-6 (Navigation).
Next Task: FE-TASK-8 (Chat Service).
FE-TASK-8: Implement ChatService
Name/Description: Create the service to communicate with the backend /v1/chat/prompt API endpoint.
Input: Backend API URL. AuthenticationService providing Firebase ID token. http package.
Expected Output: ChatService class with sendMessage method returning Future<ChatResponseData>.
Steps:
8.1: Create src/chat/chat_service.dart.
8.2: Define ChatRequestData and ChatResponseData Dart classes matching backend JSON schema.
8.3: Implement Future<ChatResponseData> sendMessage(ChatRequestData requestData):
Get ID token from AuthenticationService.
Use http.post to call the backend endpoint.
Set Authorization: Bearer <token> and Content-Type: application/json headers.
Send jsonEncode(requestData) as body.
Check response status code.
Parse JSON response (jsonDecode) into ChatResponseData on success.
Parse error JSON or use status code/text on failure, throw custom ChatServiceError.
8.4: Add basic try/catch for network errors.
Depends on: FE-TASK-4 (Auth Token), Backend API (Task ORCH-3).
Next Task: FE-TASK-9 (Chat Manager).
FE-TASK-9: Implement ChatManager & Integrate with UI
Name/Description: Create the ChatManager (or Bloc/Provider) to manage chat state and connect the UI to the ChatService.
Input: ChatScreen UI (FE-TASK-7), ChatService (FE-TASK-8), State Management solution.
Expected Output: Functional chat flow: user sends message, loading state shown, backend called, response displayed.
Steps:
9.1: Create src/chat/chat_manager.dart (or chat_bloc.dart, chat_provider.dart).
9.2: Define state: List<ChatMessage> messages, String? sessionId, bool isLoading, String? error.
9.3: Implement sendUserMessage(String text) method/event:
Get userId from AuthenticationService.
Create user ChatMessage, add to state (update UI).
Create loading assistant ChatMessage, add to state (update UI). Set isLoading = true.
Call await ChatService.sendMessage(...) with text, userId, sessionId.
On success: Update loading message with response text, update sessionId, set isLoading = false.
On error: Update loading message status to error, set error state, set isLoading = false.
9.4: Connect ChatScreen UI:
Use state management solution to get messages, isLoading, error state from ChatManager.
Bind ListView to the messages state.
Bind MessageInputBar's send action to ChatManager.sendUserMessage.
Show loading/error states appropriately in the UI.
Depends on: FE-TASK-7, FE-TASK-8.
Next Task: FE-TASK-10 (Event List UI).
FE-TASK-10: Implement EventListScreen UI
Name/Description: Build the static UI for displaying calendar events.
Input: Flutter UI knowledge.
Expected Output: EventListScreen widget with list view area, placeholders for events, loading/error indicators.
Steps:
10.1: Create src/events/event_list_screen.dart.
10.2: Create src/ui/widgets/calendar_event_tile.dart to display event summary (title, time).
10.3: In EventListScreen, use Scaffold, ListView.builder (or CalendarView package). Add RefreshIndicator.
10.4: Add state management (Bloc/Provider/Riverpod) for List<CalendarEvent>, isLoading, error.
10.5: Conditionally render loading indicator, error message, empty state text, or the event list.
Depends on: FE-TASK-6 (Navigation).
Next Task: FE-TASK-11 (Calendar Service).
FE-TASK-11: Implement CalendarService (Read Events - Direct API)
Name/Description: Implement event fetching directly from Google Calendar API.
Input: AuthenticationService providing Google OAuth accessToken. googleapis or http package.
Expected Output: CalendarService with fetchEvents returning Future<List<CalendarEvent>>.
Steps:
11.1: Create src/events/calendar_service.dart.
11.2: Implement Future<List<CalendarEvent>> fetchEvents(DateRange range):
Get accessToken from AuthenticationService. Handle potential null/expired token (trigger re-auth?).
Use http package or googleapis package (calendar_v3 API).
Construct API request to GET /calendars/primary/events with timeMin, timeMax, etc. Add Authorization: Bearer <accessToken> header.
Send request, handle response.
Parse JSON response items into List<CalendarEvent> objects (create CalendarEvent.fromJson). Handle date/time parsing carefully.
Return list or throw specific errors on failure.
Depends on: FE-TASK-4 (Auth Service providing access token). Requires requesting calendar.readonly scope during login.
Next Task: FE-TASK-12 (Integrate Calendar), FE-TASK-14 (Cache Service).
FE-TASK-12: Integrate CalendarService with EventListScreen
Name/Description: Connect EventListScreen to fetch and display events via CalendarService, handle states, and implement pull-to-refresh.
Input: EventListScreen UI (FE-TASK-10), CalendarService (FE-TASK-11), State Management.
Expected Output: EventListScreen displays real events, shows loading/error states correctly.
Steps:
12.1: In EventListScreen's Bloc/Provider/Notifier, implement a loadEvents method/event.
12.2: Inside loadEvents: Set isLoading=true. Check connectivity. If online, call await CalendarService.fetchEvents(). On success, update state with events, set isLoading=false. On error, set error state, set isLoading=false. (Offline handling in FE-TASK-14).
12.3: Trigger loadEvents initially (e.g., in initState or equivalent).
12.4: Connect RefreshIndicator's onRefresh callback to trigger loadEvents.
12.5: Ensure the UI correctly reflects the isLoading, error, and events list state.
Depends on: FE-TASK-10, FE-TASK-11.
Next Task: FE-TASK-13 (Preferences), FE-TASK-14 (Caching).
FE-TASK-13: Implement PreferenceService & UI
Name/Description: Create PreferencesScreen UI and PreferenceService to load/save settings using CacheService.
Input: State Management. CacheService definition.
Expected Output: Functional PreferencesScreen. Settings persist locally.
Steps:
13.1: Define PreferenceService.dart. Implement getPreferences() and savePreferences(prefs) methods, using CacheService internally with a specific key (e.g., 'userPreferences'). Define Preferences data class.
13.2: Create src/preferences/preferences_screen.dart. Build UI with controls (e.g., SwitchListTile, DropdownButton).
13.3: Use state management to hold Preferences state.
13.4: Load preferences via PreferenceService.getPreferences() on screen init.
13.5: When user changes a setting, update the state and call PreferenceService.savePreferences(). Show confirmation (e.g., ScaffoldMessenger.showSnackBar).
Depends on: FE-TASK-6 (Navigation), FE-TASK-14 (Cache Service).
Next Task: FE-TASK-15 (Analytics).
FE-TASK-14: Implement CacheService (Local Storage)
Name/Description: Implement the CacheService using Hive (or chosen alternative) for local data persistence.
Input: Hive package installed. Data models (UserProfile, CalendarEvent, ChatMessage).
Expected Output: CacheService class capable of saving/loading structured data locally.
Steps:
14.1: Create src/core/cache_service.dart.
14.2: Initialize Hive in main.dart: await Hive.initFlutter().
14.3: Generate Hive Adapters for your data models (UserProfile, CalendarEvent, ChatMessage, Preferences) using hive_generator and build_runner. Register adapters.
14.4: Implement CacheService methods (saveObject, getObject, saveList, getList, deleteItem). Use Hive.openBox() and box methods (put, get, delete). Handle potential errors.
14.5: Ensure service is provided via dependency injection/provider.
Depends on: FE-TASK-1 (Hive install). Used by FE-TASK-11 (optional event cache), FE-TASK-9 (chat history cache), FE-TASK-13 (prefs).
Next Task: FE-TASK-16 (Offline Logic).
FE-TASK-15: Implement AnalyticsService & Logging
Name/Description: Create AnalyticsService wrapper and integrate logging calls.
Input: Configured firebase_analytics. Defined list of events to track.
Expected Output: AnalyticsService class. Events logged to Firebase console.
Steps:
15.1: Create src/services/analytics_service.dart.
15.2: Implement methods like logLogin(), logSendMessage(), logError(name, params), etc., calling FirebaseAnalytics.instance.logEvent(...) internally.
15.3: Call these methods from relevant places (AuthenticationService, ChatManager, error handlers).
15.4: Verify events using Firebase DebugView.
Depends on: FE-TASK-2. Integration points depend on most other tasks.
Next Task: FE-TASK-16, FE-TASK-17.
FE-TASK-16: Implement Offline Viewing Logic
Name/Description: Integrate CacheService and ConnectivityService to enable offline viewing of events and preferences.
Input: CacheService (FE-TASK-14), ConnectivityService wrapper around connectivity_plus.
Expected Output: App displays cached data when offline.
Steps:
16.1: Implement ConnectivityService.dart providing Stream<ConnectivityResult> or ValueNotifier<bool>. Provide via state management.
16.2: Modify EventListScreen's loadEvents (FE-TASK-12): Check connectivity status from ConnectivityService. If offline, call CacheService.getCachedEvents(). Display offline banner.
16.3: Modify ChatScreen: Check connectivity. If offline, disable MessageInputBar, show offline banner. Load initial history from CacheService.getCachedChatHistory().
16.4: Ensure PreferencesScreen (FE-TASK-13) always loads from CacheService first.
Depends on: FE-TASK-14, Connectivity package install. Modifies FE-TASK-12, FE-TASK-9, FE-TASK-13.
Next Task: FE-TASK-17.
FE-TASK-17: Implement Network Retry Logic
Name/Description: Add retry logic to ChatService and CalendarService.
Input: Implemented ChatService, CalendarService. Retry package (e.g., retry) or manual implementation knowledge.
Expected Output: Network requests automatically retry on transient failures.
Steps:
17.1: Add retry package to pubspec.yaml.
17.2: In ChatService.sendMessage, wrap the http.post call with retry() logic. Configure attempts, delays, and retry conditions (e.g., retry on network errors or 5xx status codes).
17.3: In CalendarService.fetchEvents, apply similar retry() logic around the API call.
17.4: Ensure the final error is thrown if all retries fail.
Depends on: FE-TASK-8, FE-TASK-11.
Next Task: FE-TASK-18.
FE-TASK-18: Testing, Polish & Release Prep
Name/Description: Perform final testing, UI/UX refinement, and prepare for release.
Input: Feature-complete application from previous tasks.
Expected Output: Stable, tested MVP build ready for deployment.
Steps:
18.1: Manual Testing: Test all flows (login, chat, events online/offline, prefs, errors) on target platforms (iOS, Android, Web).
18.2: Automated Testing: Write Widget tests for key screens/widgets. Write Unit tests for services/blocs/providers (mock dependencies). (Integration tests optional).
18.3: UI/UX Polish: Review design consistency, responsiveness, accessibility, loading/error states.
18.4: Performance: Check for jank, optimize list rendering, monitor memory using DevTools.
18.5: Bug Fixing: Address issues found in testing.
18.6: Release Prep: Configure app icons, splash screens, version numbers. Generate signed builds (Android Keystore, iOS Certificates/Provisioning). Configure PWA manifest (web/manifest.json).
Depends on: All previous tasks.
Next Task: Deployment.
