Hey I want to implement an workout report when the user's workout session ends.

I'm not 100% sure what the information we have access to is and where, but I think that during the workout session we collect information like # reps, session time, included workouts, idk what else, and I think we store it in the frontend cache/session. When the session ends when the user stops recording, we should send this session data to the backend to store perhaps in a 'sessions' table linked to the user, and as part of this same workflow, we should send the session data to an LLM for more detailed analysis. We already have an endpoint for this actually, perhaps we should add an endpoint for the actual session data db storage as well.

Fortunately as well, the frontend view on end of session is already separated into showing the session data and the ai analysis, which loads before populating. We can add this part now. 

If we store this ai analysis in the db as well during the analysis endpoint before it gets back to the frontend, we can also pull this and populate the landing page on the user's next sign in. 

