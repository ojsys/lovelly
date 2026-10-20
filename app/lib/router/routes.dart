/// Route paths from the PRD screen map.
abstract final class Routes {
  static const splash = '/splash';
  static const welcome = '/welcome';
  static const phone = '/onboarding/phone'; // not in the canvas (questions.md #9)
  static const otp = '/onboarding/otp';
  static const basics = '/onboarding/basics';
  static const selfie = '/onboarding/selfie';
  static const permissions = '/onboarding/permissions';
  static const review = '/onboarding/review'; // selfie in manual review (no design)
  static const removed = '/onboarding/removed'; // under-18 account removed (no design)
  static const suspended = '/suspended'; // SF-6 (no design)
  static const safetyEnded = '/match/ended'; // SF-2 (no design)
  static const friendChat = '/friends/chat/:chatId';
  static const friendReport = '/friends/chat/:chatId/report';
  static const calling = '/friends/calling'; // outgoing friend call (no design)
  static const incomingCall = '/call/incoming'; // FR-16 (no design)
  static const home = '/home';
  static const searching = '/match/searching';
  static const videoCall = '/call/video';
  static const voiceCall = '/call/voice';
  static const chat = '/chat/:id';
  static const friends = '/friends';
  static const report = '/report/:sessionId';
  static const profileEdit = '/profile/edit';
  static const coins = '/coins';
  static const gifts = '/call/gifts';
  static const plus = '/plus';
  static const confirmCharge = '/match/confirm-charge';
}
