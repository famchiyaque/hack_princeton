In this file I'm going to explain the current state of the spoken live feedback in the app, the new implementation, and possibilities for even better implementation.

Currently, during recording, random point patterns are appearing on the screen, and every 2 seconds or so the phone speaks either 'go deeper' or 'good form' repeatedly. This is obviously really bad quality feedback. The input data are also poorly acquired points from apple vision. I don't know about the quality or robustness of our algorithm that processes these points to determine the output. But in any case I don't know how good this solution is in general.

We chose this workflow for app speed, low usage cost, and development simplicity. I was outvoted. So help me brainstorm how we can optimize this current solution. Can we make the frontend algorithm more advanced, to be able to recognize and evaluate different specified workouts? And get actually real/relevant output options?

I understand in this case we can simply generate audio files one time with eleven labs and store them in the front for immediate 0 latency access, but I won't transcribe these predefined outputs to audio files from elevenlabs until the algorithm is better.

In addition, I'd like to propose a different flow, to exist as an option. We actually evaluate the apple vision data and/or pure video data with a real LLM. This could mean storing vision data and or 10-15s of video data in memory, sending it to be evaluated by a more advanced reasoning model, and receiving more tailored output repeatedly the output, in text form I imagine, would then need to be sent to eleven labs agent api for real-time text-to-speech transcribing as well. That's my proposal.

Make it a preference/toggle option for the user in the UI so I can demonstrate both options. Before any of this though, investigate these possibilities and give me feedback.



