# FitCraft AI: clickable prototype

A research prototype for tailors and wedding coordinators: one group order (Aso-ebi), each guest's outfit,
measurements, payments and fit records, plus the read-only coordinator link. Sample data only, saved in the
browser. Blueprint: FitCraft AI Product Blueprint v2.

## Run it

    npm install
    npm run dev        # http://localhost:5173

## Deploy (separate Firebase project, not SKILL.SCH's)

    npm run build
    firebase login
    firebase use --add            # pick the FitCraft project
    firebase deploy --only hosting

## What to test with tailors

See the About tab in the app: five tasks, timed, plus the pricing question.
