The current state of the app:

Positive

The points mapped to the user's body are much better. Both real-time messages and audio are being communicated to the user every few seconds as intended. 

Negative

The audio is still robotic since we haven't transcribed anything with eleven labs. The messages to the user are not necessarily relevant to what the user is doing- it seems the app is only checking for whether the user is doing squats or not. For squats 
The recogniction/classification isn't there.

Ideal Working Functionalities

- visual feedback, drawing the line on the screen for the movement to follow. for example, for a squat, if our app draws a line on the screen for a user to follow to stabilize their rep.
- audibal feedback is well timed and combined with the visual feedback
- recognition of various exercises. high priority. in our demo, it's very crucial that our model/algorithm accurately recognizes which exercise the user is actually doing. as of right now, it only seems to be analyzing the user's movements for a squat.
- injury risk on at least on one exercise (deadlift for example)
- form correction (at least on one exercise)
- squat, deadlift, bench

So we have a lot of ideas. 

We need a modular approach to our exercise classifcation and feedback. Let's say we want to be able to identify which of the following the user is doing: squat, bench, or deadlift (the basic compount movements), and of course, the model should be able to recognize if the user is clearly not doing any of these movement. 
The screen should display the current excercise. 
Once classified, each exercise should have its own model dedicated to constant processing of user movement through the apple vision points for feedback catered to those specific movements. The original classification itself shouldn't be too hard- the overall point distribution on user joints will be predictably distinct for each exercise: a side view for each exercise- for squats, where the leg joints contract downward and backleg possibly not visible. For deadlift, its the arm joints moving up and down, and for bench the upper body is horizontal. 
This is a core and necessary function. Improved audible and visual feedback can come after we prove this part. For the feedback for now, we can even really predefine all the possibilities for each exercise: for a deadlift, if the points are not moving perfectly vertical, the message should be to fix that. If the legs are moving, then tell the user to keep strong legs. For squats, their own set of predefined risks/recomentdations based on joint positions. We don't necessarily have to return something every couple seconds to the user, either. We can create a separate audible/message data structure that is populated if a risk is detected, and polled every few seconds and any message is popped. This means, if the user is doing well, the structure isn't being filled, and we don't give the user any feedback. Maybe this could become more intelligent to optionally also give positive feedback, but not every time.

This is a necessary base for our app's functionality. Once we prove this, we can continue working on other things like drawing lines on the screen for the user to follow (visual feedback) and refining the feedback options and transcribing with eleven labs.
