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
    firebase deploy --only hosting

## What to test with tailors

See the About tab in the app: five tasks, timed, plus the pricing question.

## Android app (Flutter / Dart) — `mobile/`

The tailor app as a real Android app, with **Measure with photos (AI)**: the customer's height plus a front
and a side photo; Google ML Kit (pose detection + body segmentation) runs on the phone, offline, and
`lib/measure/body_math.dart` turns the body points and outlines into measurements. The tailor reviews every
value (Good / Check / Estimate / Measure by hand) and confirms before anything is saved.

    cd mobile
    flutter test                 # measurement maths
    flutter build apk --release  # build/app/outputs/flutter-apk/app-release.apk

Lengths (shoulder, sleeve, garment lengths) come from body points; chest, waist and hip are estimates from
the front width and side depth. Calibrate the ratios in body_math.dart against tape measurements in the pilot,
or plug in a scan vendor behind the same review screen for tailoring-grade accuracy.
