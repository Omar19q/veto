# Quick visual acceptance checks

- Home: pickup label, destination CTA, and four service icons fit without essential-page scroll at default scale.
- A customer may drag the optional home sheet; map remains interactive.
- Pickup: actual pin visible, original GPS coordinates unchanged, manual description prompted when address is unknown.
- Destination: search field visible immediately and recent places do not require another selection page.
- Fare: service comparison and server price appear together; wallet and promotional values are unchanged from server contract.
- Searching: price and status readable, optional boost accessible but not dominant.
- Sound: physical-device testing required; don't infer mobile speaker volume from browser playback.
- Language: localize all newly added Arabic customer-facing copy before supporting full English UX.
- Release: build signed Android artifacts separately, confirm 0 compile errors and critical regression flows.
