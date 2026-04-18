Here are all the things we want to clear up, add, change, delete, and 
more to our codebase.

To start, can you clear up how the analysis is being generated? are we
communicating with anthropic? we should define our own algorithm/model for coordinate and points analysis, in the frontend for speed. 

Help me define how are we going to build this

At least according to my own understanding, we have a styled swift app that already has the core functionality of filming the user and channeling live feedback through audio using native ios tools, correct?

The actual processing/feedback is powered by a proprietary algorithm directly in the frontend that takes in the user's arms and legs points from the vision pro library, calculates angles and such, compares them to ideal point/distance ratios (something like this lol not exactly how I'm describing it), determines inconsistencies or errors in the user's form, and turns those inconsistencies into specific text instructions for improvement. 

That's for during the session. At the end of the session, when the user stops recording, we should generate a session report. Maybe count the amount of reps, sets, key risks in their form, things they did well, not sure what else. 

Not to remove already existing functionalities, just making sure we have this core logic. The key workouts we want to be able to audit are: squats, deadlifts, push ups, jumping jacks, maybe curls. 

That's for the frontend. This processing and functionality lives directly in the app for speed and ease. The backend also has a part though. We need to collect information about the user to make the app feel tailored. To start, the onboarding gives us data about the user's goals: current physical state, health conditions, body goals. We can generate a plan and track progress this way, whose key metrics should be visible on the app's landing page. 

The session report should be based on session data, meaning we're collecting their session data somewhere. Maybe we can just do that within the app itself, and then store it all at the end of the session in the backend. And I'm not sure whether we should define report analysis algorithms in the backend ourselves or just pass the session data to an AI model, give me your take. 

Stored sessions should be saves in the workouts tab of the app. Backend data should feed these other parts of the app, like the workouts tab. The insights tab should include metrics about the user's progress and plan in more detail. Of course the profile tab should include user information.

Audit our current backend to make sure it's capable of this.

Think about blindspots in our system requirements and design. That being said, we're on a short time schedule and need something tangible. 

I can't test it though. I need one of my friends to, they have Macs. So give me clear instructions to test it on one of their macbooks please. 