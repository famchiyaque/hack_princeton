"""Reference exercise data — seeded on startup if table is empty."""

EXERCISES = [
    {
        "id": "pushup",
        "name": "Push-Up",
        "reference_data": {
            "phases": [
                {
                    "name": "bottom",
                    "referenceAngles": {
                        "elbowAngle": {"min": 70, "max": 100},
                        "hipAngle":   {"min": 160, "max": 180},
                        "spineAngle": {"min": 160, "max": 180},
                    },
                },
                {
                    "name": "top",
                    "referenceAngles": {
                        "elbowAngle": {"min": 155, "max": 180},
                        "hipAngle":   {"min": 160, "max": 180},
                        "spineAngle": {"min": 160, "max": 180},
                    },
                },
            ],
            "corrections": {
                "elbowAngle_high": "Go deeper",
                "elbowAngle_low":  "Fully extend your arms",
                "hipAngle_low":    "Keep your hips up",
                "spineAngle_low":  "Straighten your back",
            },
        },
    },
    {
        "id": "squat",
        "name": "Squat",
        "reference_data": {
            "phases": [
                {
                    "name": "bottom",
                    "referenceAngles": {
                        "kneeAngle":  {"min": 60,  "max": 100},
                        "hipAngle":   {"min": 60,  "max": 100},
                        "spineAngle": {"min": 150, "max": 180},
                    },
                },
                {
                    "name": "top",
                    "referenceAngles": {
                        "kneeAngle":  {"min": 155, "max": 180},
                        "hipAngle":   {"min": 155, "max": 180},
                        "spineAngle": {"min": 150, "max": 180},
                    },
                },
            ],
            "corrections": {
                "kneeAngle_high":  "Go deeper",
                "kneeAngle_low":   "Don't go too deep",
                "hipAngle_low":    "Open your hips",
                "spineAngle_low":  "Keep your chest up",
            },
        },
    },
    {
        "id": "plank",
        "name": "Plank",
        "reference_data": {
            "phases": [
                {
                    "name": "hold",
                    "referenceAngles": {
                        "elbowAngle": {"min": 85,  "max": 95},
                        "kneeAngle":  {"min": 160, "max": 180},
                        "hipAngle":   {"min": 160, "max": 180},
                        "spineAngle": {"min": 160, "max": 180},
                    },
                },
            ],
            "corrections": {
                "hipAngle_low":   "Raise your hips",
                "hipAngle_high":  "Lower your hips",
                "spineAngle_low": "Straighten your back",
            },
        },
    },
    {
        "id": "lunge",
        "name": "Lunge",
        "reference_data": {
            "phases": [
                {
                    "name": "bottom",
                    "referenceAngles": {
                        "kneeAngle":  {"min": 85,  "max": 100},
                        "hipAngle":   {"min": 85,  "max": 100},
                        "spineAngle": {"min": 150, "max": 180},
                    },
                },
                {
                    "name": "top",
                    "referenceAngles": {
                        "kneeAngle":  {"min": 155, "max": 180},
                        "hipAngle":   {"min": 155, "max": 180},
                        "spineAngle": {"min": 150, "max": 180},
                    },
                },
            ],
            "corrections": {
                "kneeAngle_high":  "Lower your back knee",
                "spineAngle_low":  "Keep your torso upright",
                "hipAngle_low":    "Drive your hips forward",
            },
        },
    },
]


def seed(db):
    from models import Exercise
    if db.query(Exercise).count() == 0:
        for ex in EXERCISES:
            db.add(Exercise(id=ex["id"], name=ex["name"], reference_data=ex["reference_data"]))
        db.commit()
