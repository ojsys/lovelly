/// Voice-call icebreakers (05). Placeholder list until the real one arrives
/// (docs/questions.md #22). The first is from the design.
const icebreakers = [
  'If you could only eat one Nigerian dish forever, what is it and why?',
  'What song is stuck in your head this week?',
  'Jollof: Nigerian or Ghanaian? Defend your answer.',
  'What’s the best advice an older person ever gave you?',
  'If you could live in any city for a year, where would it be?',
  'What’s something you’re weirdly good at?',
  'Which Nollywood film should everyone watch at least once?',
  'What did you want to be when you were ten?',
  'What’s your perfect Saturday?',
  'Which artist would you queue all night to see live?',
  'What’s a small thing that always makes your day better?',
  'If you started a business tomorrow, what would it be?',
  'What’s the most beautiful place you’ve been to?',
  'Tea, coffee, zobo or Chapman?',
  'What’s a skill you’d love to learn this year?',
  'Which book or podcast changed how you think?',
  'What’s your go-to karaoke song?',
  'Who’s the funniest person you know, and why?',
  'What would your dream holiday look like?',
  'Football: who wins the next AFCON?',
  'What’s a tradition from home you love?',
  'What’s the last thing that made you laugh out loud?',
  'If you could have dinner with anyone, who would it be?',
  'What app could you not live without?',
  'Suya or shawarma for a late-night snack?',
  'What’s something you’re proud of from this year?',
  'Which language would you love to speak fluently?',
  'What’s your favourite way to relax after a long week?',
  'Which superpower would actually be useful in Lagos traffic?',
  'What’s one thing on your bucket list?',
];

/// Both people see the same question: it's picked from the session id.
int icebreakerFor(String sessionId) =>
    sessionId.codeUnits.fold<int>(0, (h, c) => (h * 31 + c) & 0x7fffffff) % icebreakers.length;
