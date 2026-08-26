# First-run copy inventory

User-facing strings for the universal first-run journey. Sources stay local. None of this
diagnoses a sleep condition or promises better sleep.

| Screen | State | Copy | Source IDs | Rationale |
|---|---|---|---|---|
| Welcome · phone resting place | Narrative 1 | Put the phone to bed before you. Counting Sheep helps you make a little space between your screen and your sleep — before bed, overnight, and after you wake. Wind down without the scroll. Keep your phone out of reach overnight. Start your morning before your feed does. | — | Explains the complete ritual beside the dedicated phone-resting cottage illustration. |
| Welcome · Ollie and the Farm | Narrative 2 | Ollie keeps watch. Ollie helps guard your screen time when it might get in the way of rest. Each night you complete a Wind Down, he’ll search for lost sheep to bring back to your Farm. Need some space from your phone during the day? Phone Away is there for that, too. | — | Introduces Ollie, the Farm payoff, and Phone Away as a short story rather than feature documentation. |
| Questionnaire | Six-question chapter | YOUR STARTING POINT · QUESTION 2 OF 6. The questionnaire remains skippable through the persistent action area; local-storage copy is not repeated after every question. | — | One full-width, categorical question per viewport; stage and question progress remain distinct. |
| Starting point | After explicit answers | YOUR STARTING POINT. What we noticed. A gentle place to begin. | Explicitly supported primary/secondary patterns and relevant `WindDownGuidanceLibrary` IDs | Plain-language, non-clinical explanation without a displayed score, unsupported claim, or gift matching. |
| Welcome gift | Completed or skipped questionnaire | A little something for starting. Ollie picked out a few things for your first night. Choose one for your Shepherd. Wear now / Keep for later. | Existing Wool Field Hat, Moss Work Coat, and Moonlit Coat catalogue items | Everyone chooses one immediately claimed gift; equipment and avatar appearance use the production Farm. |
| Questionnaire skipped | Result omitted, gift retained | Skip questions. | — | Skip removes only the behavioral explanation; the same welcome-gift eligibility remains. |
| Schedule and reminder | Optional permission | A gentle reminder. A reminder does not start it for you. Enable Wind Down reminders / Turn reminders off. | — | Notification authorization follows an explicit explanation; automatic Wind Down remains off. |
| Saved plan | Ready, denied, or reminders off | Your next Wind Down is ready. App protection ready. On at 10:00 PM / Off / On — notification permission needed. When it is time, open Counting Sheep and put your phone away to begin. | Actual next planned occurrence, ordered routines, protection readiness, and notification authorization | Summary is derived from real state and never implies an automatic start. |
| Practice offer | Guide | This creates a real Nights record. It is not a protected night, and it does not add to the usual Phone Away search meter. | — | Honest about rewards and meters. |
| Practice reward | New sheep granted | Ollie brought a second sheep home. | `pippin` | Only when this completion minted the sheep. |
| Practice reward | Sheep already granted | Practice is in Nights. Your welcome-gift sheep is still on the Farm. | — | Replay must not pretend a second Pippin arrived. |
| Farm chapter offer | First user-initiated Farm visit | Want the four-tip Farm tour? Meet the flock, The Barn, the wardrobe, and Ollie’s Search. Show me / Explore on my own. | — | Farm guidance is opt-in after the Home exploration pause. |
| Wardrobe | Gift owned | Welcome gift · Owned. Wear / Take off. | Wearable item ID | The gift is visible without a wool price or progression unlock. |
| Continue card | Paused chapter only | Resume Home basics / Resume the Farm tour. Resume / Dismiss for now. | — | Resume changes the visible destination in the same interaction. |
| Slumber Party | Available | Create a Slumber Party / Join with a code / Do this later. | — | Join focuses the code field. |
| Slumber Party | Unavailable | Slumber Party is not available in this copy of Counting Sheep. Wind Down, the Farm, and Nights are ready. | — | No feature-flag language. |
| Screen Time | Onboarding + Settings | Choose the apps or categories you would like to pause while your phone rests. Counting Sheep stays available. Finish app protection setup to continue. | — | Consent before the system prompt; first-run completion still requires successful protection. |
| Health | Settings | Apple Health can place optional sleep duration and stages beside your Wind Down record in Nights. It does not decide whether Wind Down was completed or whether Ollie finds a sheep. | — | Optional context, not a score. |
