# Ediz OS design

The primary product is a real SwiftUI iPhone app, tested on iPhone 17 Pro. The visual language is warm black, soft ivory, restrained identity colors, humanist Avenir Next typography and genuine iOS 26 liquid-glass controls. Moshia uses warm ivory; Personal uses olive. No purple, decorative pictures, thin dividers or repeated arrow motifs remain in the revised Today and Spaces layouts.

Today leads with the date and “Today, Ediz.” Its next-move area presents saved priorities with explainable reasons, or a truthful calm empty state. Capture and Import are immediate glass actions. Five solid neutral rows provide working shortcuts into leads, setlist, chapters, school and personal capture. Recent work, commitments, reviews and meaningful updates appear when relevant. Fake personal records are never used to fill the production interface.

Phone navigation has five destinations and a moving glass selection. Native TabView preserves platform gestures and is enhanced with a horizontal UIKit pan recognizer using public APIs. Capture is a full destination during scrubbing, while contextual capture uses dismissible native sheets. Web pointer handling commits on drag release and preserves ordinary taps. Native swipe-back and sheet dismissal are covered by automated tests.

Content remains solid and readable; glass belongs to navigation and controls. Layout follows native safe areas and keyboard behavior. Web controls provide 44px touch targets, reduced-motion and reduced-transparency fallbacks. Humanist fonts are self-hosted in the web companion, with installed Avenir Next preferred on iPhone. Scrolling module buttons cannot shrink into one another.

Focus is a quiet work surface with an elapsed timer, no countdown and no progress ring. A neutral circular timer gives the work room. Complete/Finish appears after beginning and receives less emphasis than the working control. Assistant supports contextual conversation and reviewed reminder drafts, with clear limits on its local rules and optional models.

References inspected: Things grouping, Flighty information hierarchy, Apple materials guidance, Practical Typography and Nielsen Norman Group visual hierarchy. Uiverse blocked automated gallery access; its official Galaxy MIT source was accessible. Inputs, completion controls and switches are adapted and attributed in THIRD_PARTY_NOTICES.md. Native controls remain platform controls.

The approved generated concept is a design reference, not build evidence. Actual native screenshots, seven passing gesture/workflow tests and an unsigned device Release archive are preserved in GitHub Actions run 36847582563. Browser screenshots cover Today, Spaces, Focus, Assistant and desktop. Physical-device testing and native installation require Apple signing and device access.
