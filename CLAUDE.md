# ClaudeCodeVoice Project Instructions

## Running Xcode Apps

To build and run this Xcode app, use AppleScript to control Xcode:

```bash
osascript -e 'tell application "Xcode" to activate' -e 'tell application "System Events" to keystroke "r" using command down'
```

This will:
1. Activate Xcode (bring it to front)
2. Press Cmd+R to build and run the current scheme

## Project Overview

This is a macOS app that provides always-on voice transcription using OpenAI's Whisper API.

## Development Workflow

1. Make code changes
2. Commit and push immediately after each change
3. Run the app using the AppleScript command above
4. Test the feature
5. Move to next feature

## Current Features

- [x] Always-on microphone listening
- [x] Real-time audio level visualization
- [ ] Voice activity detection
- [ ] OpenAI Whisper integration
- [ ] Transcription display